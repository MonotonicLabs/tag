import Foundation

struct GitStatusSummary: Hashable, Sendable {
  var hasUncommitted: Bool
  var hasUnpushed: Bool
}

struct CmdResult: Hashable, Sendable {
  var stdout: String
  var stderr: String
  var exitCode: Int32
}

enum CmdError: Error, CustomStringConvertible {
  case failed(cmd: String, args: [String], cwd: String?, exitCode: Int32, stderr: String)

  var description: String {
    switch self {
    case let .failed(cmd, args, cwd, exitCode, stderr):
      let cwdSuffix = cwd.map { " (cwd: \($0))" } ?? ""
      let err = stderr.isEmpty ? "<no stderr>" : stderr
      return "\(cmd) \(args.joined(separator: " ")) exited \(exitCode)\(cwdSuffix): \(err)"
    }
  }
}

final class ProcessRunner: Sendable {
  func run(_ cmd: String, _ args: [String], cwd: URL?) throws -> CmdResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [cmd] + args
    process.currentDirectoryURL = cwd

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()

    // Avoid deadlocks by draining stdout/stderr concurrently.
    let group = DispatchGroup()
    var stdoutData = Data()
    var stderrData = Data()

    group.enter()
    DispatchQueue.global(qos: .userInitiated).async {
      stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
      group.leave()
    }

    group.enter()
    DispatchQueue.global(qos: .userInitiated).async {
      stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
      group.leave()
    }

    process.waitUntilExit()
    group.wait()

    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
    let stderr = String(data: stderrData, encoding: .utf8) ?? ""
    return CmdResult(
      stdout: stdout.trimmingCharacters(in: .newlines),
      stderr: stderr.trimmingCharacters(in: .newlines),
      exitCode: process.terminationStatus
    )
  }
}

enum Git {
  static func isRepo(atPath dirPath: String) -> Bool {
    let gitPath = (dirPath as NSString).appendingPathComponent(".git")
    var isDir = ObjCBool(false)
    if FileManager.default.fileExists(atPath: gitPath, isDirectory: &isDir) {
      return true
    }
    return false
  }

  static func originUrl(atPath dirPath: String, runner: ProcessRunner) -> String? {
    let cwd = URL(fileURLWithPath: dirPath)
    let result = try? runner.run("git", ["config", "--get", "remote.origin.url"], cwd: cwd)
    guard let result, result.exitCode == 0 else { return nil }
    let trimmed = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  static func statusSummary(atPath dirPath: String, runner: ProcessRunner) -> GitStatusSummary? {
    let cwd = URL(fileURLWithPath: dirPath)
    let result = try? runner.run("git", ["status", "--porcelain=v2", "--branch"], cwd: cwd)
    guard let result, result.exitCode == 0 else { return nil }

    var hasUncommitted = false
    var upstreamMissing = true
    var aheadCount = 0

    let lines = result.stdout.split(separator: "\n", omittingEmptySubsequences: true)
    for lineSub in lines {
      let line = String(lineSub)
      if line.hasPrefix("# branch.upstream ") {
        upstreamMissing = false
        continue
      }
      if line.hasPrefix("# branch.ab ") {
        let parts = line.split(separator: " ")
        if parts.count >= 4 {
          let aheadPart = parts[2] // +N
          if aheadPart.first == "+", let n = Int(aheadPart.dropFirst()) {
            aheadCount = n
          }
        }
        continue
      }
      if !line.hasPrefix("#") {
        hasUncommitted = true
      }
    }

    let hasUnpushed = upstreamMissing || aheadCount > 0
    return GitStatusSummary(hasUncommitted: hasUncommitted, hasUnpushed: hasUnpushed)
  }
}

func extractRepoTag(from originUrl: String) -> String? {
  let trimmed = originUrl.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty else { return nil }

  var path = ""
  if let match = trimmed.range(of: #"^[^@]+@[^:]+:(.+)$"#, options: .regularExpression) {
    let fullMatch = String(trimmed[match])
    if let colonIndex = fullMatch.firstIndex(of: ":") {
      path = String(fullMatch[fullMatch.index(after: colonIndex)...])
    }
  } else if let url = URL(string: trimmed), url.scheme != nil {
    path = url.path
  } else {
    return nil
  }

  path = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  if path.hasSuffix(".git") {
    path = String(path.dropLast(4))
  }
  return path.isEmpty ? nil : path
}
