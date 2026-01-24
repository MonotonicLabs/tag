import Foundation

enum EntryKind: Sendable {
  case dir
  case file
}

struct EntryTask: Sendable {
  var name: String
  var fullPath: String
  var displayPath: String
  var kind: EntryKind
}

struct TagRunSummary: Sendable {
  var lines: [String]
  var errors: [String]
}

struct ScanProgress: Sendable {
  var total: Int
  var completed: Int
  var currentPath: String?

  var fraction: Double {
    guard total > 0 else { return 0 }
    return Double(completed) / Double(total)
  }
}

struct FolderScanResult: Sendable {
  enum Status: Sendable {
    case synced
    case localChanges
    case localOnly
    case noGit
    case file
    case error(String)
  }

  let path: String
  let status: Status
  let message: String
  let origin: String?  // Git remote origin URL or extracted repo tag (owner/repo)
}

struct Tagger: Sendable {
  private let config: TaggerConfig
  private let runner: ProcessRunner
  private let commentWriter: FinderCommentWriter

  init(config: TaggerConfig, runner: ProcessRunner = ProcessRunner()) {
    self.config = config
    self.runner = runner
    self.commentWriter = FinderCommentWriter(runner: runner)
  }

  static func defaultConcurrency() -> Int {
    let cpuCount = ProcessInfo.processInfo.processorCount
    return min(8, max(2, cpuCount))
  }

  func collectTasks(roots: [String]) async -> (tasks: [EntryTask], errors: [String]) {
    var tasks: [EntryTask] = []
    var errors: [String] = []
    let multiRoot = roots.count > 1

    for root in roots {
      var isDir = ObjCBool(false)
      if !FileManager.default.fileExists(atPath: root, isDirectory: &isDir) || !isDir.boolValue {
        errors.append("Not a directory: \(root)")
        continue
      }

      let entries: [String]
      do {
        entries = try FileManager.default.contentsOfDirectory(atPath: root)
      } catch {
        errors.append("Failed to list \(root): \(error.localizedDescription)")
        continue
      }

      for name in entries {
        let fullPath = (root as NSString).appendingPathComponent(name)
        var entryIsDir = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: fullPath, isDirectory: &entryIsDir) else { continue }
        let kind: EntryKind = entryIsDir.boolValue ? .dir : .file
        let displayPath = multiRoot ? fullPath : name
        tasks.append(EntryTask(name: name, fullPath: fullPath, displayPath: displayPath, kind: kind))
      }
    }

    return (tasks, errors)
  }

  func run(roots: [String], concurrency: Int) async -> TagRunSummary {
    await run(roots: roots, concurrency: concurrency, onProgress: nil, onResult: nil)
  }

  func run(
    roots: [String],
    concurrency: Int,
    onProgress: (@Sendable (ScanProgress) async -> Void)?,
    onResult: (@Sendable (FolderScanResult) async -> Void)?
  ) async -> TagRunSummary {
    let collected = await collectTasks(roots: roots)
    var lines: [String] = []
    var errors = collected.errors

    let tasks = collected.tasks
    if tasks.isEmpty {
      return TagRunSummary(lines: [], errors: errors)
    }

    let total = tasks.count
    var completed = 0
    let limit = max(1, min(concurrency, tasks.count))

    await onProgress?(ScanProgress(total: total, completed: completed, currentPath: nil))

    await withTaskGroup(of: (line: String?, error: String?, result: FolderScanResult?).self) { group in
      var iterator = tasks.makeIterator()

      func addOne(_ task: EntryTask) {
        group.addTask {
          do {
            let (line, result) = try await processEntryWithResult(task)
            return (line, nil, result)
          } catch {
            let result = FolderScanResult(
              path: task.fullPath,
              status: .error(error.localizedDescription),
              message: "Failed to tag",
              origin: nil
            )
            return (nil, "Failed to tag \(task.displayPath): \(String(describing: error))", result)
          }
        }
      }

      for _ in 0..<limit {
        if let task = iterator.next() {
          addOne(task)
        }
      }

      while let result = await group.next() {
        completed += 1

        if let line = result.line {
          lines.append(line)
        }
        if let error = result.error {
          errors.append(error)
        }

        if let folderResult = result.result {
          await onResult?(folderResult)
        }

        await onProgress?(ScanProgress(total: total, completed: completed, currentPath: result.result?.path))

        if let task = iterator.next() {
          addOne(task)
        }
      }
    }

    return TagRunSummary(lines: lines.sorted(), errors: errors.sorted())
  }

  private func processEntryWithResult(_ task: EntryTask) async throws -> (String, FolderScanResult) {
    let (line, status, origin) = try await processEntryInternal(task)
    let result = FolderScanResult(path: task.fullPath, status: status, message: line, origin: origin)
    return (line, result)
  }

  private func processEntry(_ task: EntryTask) async throws -> String {
    let (line, _, _) = try await processEntryInternal(task)
    return line
  }

  private func processEntryInternal(_ task: EntryTask) async throws -> (String, FolderScanResult.Status, String?) {
    switch task.kind {
    case .file:
      let tag = config.tags.unexpectedFile
      if !tag.enabled {
        return ("Skipped tagging \(task.displayPath): \(tag.name) disabled", .file, nil)
      }
      _ = try await FinderTagging.setOrderedUserTags(atPath: task.fullPath, tags: [tag])
      return ("Tagged \(task.displayPath): \(tag.name)", .file, nil)
    case .dir:
      break
    }

    if !Git.isRepo(atPath: task.fullPath) {
      let tag = config.tags.noGitRepo
      if !tag.enabled {
        return ("Skipped tagging \(task.displayPath): \(tag.name) disabled", .noGit, nil)
      }
      _ = try await FinderTagging.setOrderedUserTags(atPath: task.fullPath, tags: [tag])
      return ("Tagged \(task.displayPath): \(tag.name)", .noGit, nil)
    }

    let originUrl = Git.originUrl(atPath: task.fullPath, runner: runner)
    let statusSummary = Git.statusSummary(atPath: task.fullPath, runner: runner)

    guard let statusSummary else {
      let tag = config.tags.noGitRepo
      if !tag.enabled {
        return ("Skipped tagging \(task.displayPath): \(tag.name) disabled", .noGit, nil)
      }
      _ = try await FinderTagging.setOrderedUserTags(atPath: task.fullPath, tags: [tag])
      return ("Tagged \(task.displayPath): \(tag.name)", .noGit, nil)
    }

    guard let originUrl else {
      let tag = config.tags.localGitOnly
      if !tag.enabled {
        return ("Skipped tagging \(task.displayPath): \(tag.name) disabled", .localOnly, nil)
      }
      _ = try await FinderTagging.setOrderedUserTags(atPath: task.fullPath, tags: [tag])
      return ("Tagged \(task.displayPath): \(tag.name)", .localOnly, nil)
    }

    let repoTag = extractRepoTag(from: originUrl)
    let hasLocalChanges = statusSummary.hasUncommitted || statusSummary.hasUnpushed
    let tag = hasLocalChanges ? config.tags.gitLocalChanges : config.tags.gitSynced
    let status: FolderScanResult.Status = hasLocalChanges ? .localChanges : .synced
    let commentSuffix = repoTag.map { "; comment: \($0)" } ?? ""

    if tag.enabled {
      _ = try await FinderTagging.setOrderedUserTags(atPath: task.fullPath, tags: [tag])
    }

    if config.writeFinderComment, let repoTag {
      try await commentWriter.setFinderComment(atPath: task.fullPath, comment: repoTag)
    }

    if tag.enabled {
      return ("Tagged \(task.displayPath): \(tag.name)\(commentSuffix)", status, repoTag)
    }
    return ("Skipped tagging \(task.displayPath): \(tag.name) disabled\(commentSuffix)", status, repoTag)
  }
}
