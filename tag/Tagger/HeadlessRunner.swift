import Foundation

private actor HeadlessScanAccumulator {
  private let roots: [String]
  private var resultsByRoot: [String: [String: FolderScanResult.Status]] = [:]
  private var origins: [String: String] = [:]
  private var lastProgressWriteAt: Date = .distantPast

  init(roots: [String]) {
    self.roots = roots
    for root in roots {
      resultsByRoot[root] = [:]
    }
  }

  func shouldWriteProgress(now: Date, progress: ScanProgress) -> Bool {
    let shouldWrite = progress.completed == progress.total || now.timeIntervalSince(lastProgressWriteAt) >= 0.25
    if shouldWrite {
      lastProgressWriteAt = now
    }
    return shouldWrite
  }

  func record(result: FolderScanResult) {
    if let origin = result.origin {
      origins[result.path] = origin
    }

    for root in roots {
      if pathIsAtOrUnderRoot(result.path, root: root) {
        resultsByRoot[root]?[result.path] = result.status
        break
      }
    }
  }

  func snapshot() -> (resultsByRoot: [String: [String: FolderScanResult.Status]], origins: [String: String]) {
    (resultsByRoot: resultsByRoot, origins: origins)
  }
}

enum HeadlessRunner {
  static func runOnce() async -> Int32 {
    let progressURL = TaggerPaths.scanProgressURL()
    let startedAt = Date()
    do {
      try ScanProgressStore.save(
        ScanProgressFile(source: .scheduled, phase: .preparing, startedAt: startedAt, updatedAt: startedAt),
        to: progressURL
      )
    } catch {
      // Best-effort: avoid failing the scan due to progress persistence issues.
    }

    do {
      defer {
        try? ScanProgressStore.clear(at: progressURL)
      }

      let configURL = TaggerPaths.configURL()
      let config = try loadOrCreateDefaultConfig(at: configURL)

      let roots = Array(
        Set(
          config.roots
            .map(normalizeInputPath)
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        )
      ).sorted()

      let concurrency = config.concurrency ?? Tagger.defaultConcurrency()
      let tagger = Tagger(config: config)
      let accumulator = HeadlessScanAccumulator(roots: roots)

      let summary = await tagger.run(
        roots: roots,
        concurrency: concurrency,
        onProgress: { progress in
          let now = Date()
          let shouldWrite = await accumulator.shouldWriteProgress(now: now, progress: progress)
          guard shouldWrite else { return }

          let file = ScanProgressFile(
            source: .scheduled,
            phase: .running,
            startedAt: startedAt,
            updatedAt: now,
            total: progress.total,
            completed: progress.completed,
            currentPath: progress.currentPath
          )
          try? ScanProgressStore.save(file, to: progressURL)
        },
        onResult: { result in
          await accumulator.record(result: result)
        }
      )

      let state = await accumulator.snapshot()
      let finishedAt = Date()
      let persistedResultsByRoot = state.resultsByRoot.mapValues { results in
        results.mapValues { PersistedFolderStatus(from: $0) }
      }
      let snapshot = ScanSnapshot(
        source: .scheduled,
        finishedAt: finishedAt,
        roots: roots,
        resultsByRoot: persistedResultsByRoot,
        origins: state.origins,
        lines: summary.lines,
        errors: summary.errors
      )
      _ = try? ScanHistoryStore.update(with: snapshot, url: TaggerPaths.scanHistoryURL())

      for line in summary.lines {
        print(line)
      }
      for error in summary.errors {
        fputs("\(error)\n", stderr)
      }
      return summary.errors.isEmpty ? 0 : 1
    } catch {
      fputs("\(String(describing: error))\n", stderr)
      return 1
    }
  }

  private static func loadOrCreateDefaultConfig(at url: URL) throws -> TaggerConfig {
    if FileManager.default.fileExists(atPath: url.path) {
      let data = try Data(contentsOf: url)
      return try JSONDecoder().decode(TaggerConfig.self, from: data)
    }

    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(TaggerConfig.default)
    try data.write(to: url, options: [.atomic])
    return .default
  }
}
