import AppKit
import Combine
import Foundation

struct RootStatusSummary {
  var synced: Int = 0
  var localChanges: Int = 0
  var localOnly: Int = 0
  var noGit: Int = 0
  var files: Int = 0
  var errors: Int = 0
  var total: Int = 0

  var hasResults: Bool { total > 0 }
}

@MainActor
final class TaggerStore: ObservableObject {
  static let shared = TaggerStore()

  @Published var config: TaggerConfig
  @Published private(set) var configURL: URL

  @Published private(set) var schedulerInstalled: Bool = false
  @Published private(set) var schedulerLoaded: Bool = false
  @Published private(set) var schedulerStartIntervalSeconds: Int?

  @Published private(set) var isRunning: Bool = false
  @Published private(set) var lastRunAt: Date?
  @Published private(set) var lastRunSource: ScanSource?
  @Published private(set) var lastScheduledRunAt: Date?
  @Published private(set) var lastManualRunAt: Date?
  @Published private(set) var lastRunLines: [String] = []
  @Published private(set) var lastRunErrors: [String] = []
  @Published var lastErrorMessage: String?

  @Published private(set) var scanProgress: ScanProgress?
  @Published private(set) var folderResults: [String: FolderScanResult.Status] = [:]
  @Published private(set) var folderOrigins: [String: String] = [:]  // path -> origin
  @Published private(set) var resultsByRoot: [String: [String: FolderScanResult.Status]] = [:]  // root -> {child path -> status}

  private var manualScanInProgress: Bool = false
  private var appSupportWatcher: DirectoryWatcher?
  private var appSupportSyncWorkItem: DispatchWorkItem?

  private init() {
    let url = TaggerStore.defaultConfigURL()
    let loaded = try? TaggerStore.loadConfig(from: url)

    self.configURL = url
    self.config = loaded ?? .default

    if loaded == nil {
      do {
        try TaggerStore.saveConfig(self.config, to: url)
      } catch {
        self.lastErrorMessage = String(describing: error)
      }
    }

    setupAppSupportWatcher()
    refreshSchedulerStatus()
    syncScheduledProgressFromDisk()
  }

  func reload() {
    do {
      config = try TaggerStore.loadConfig(from: configURL)
      lastErrorMessage = nil
    } catch {
      lastErrorMessage = String(describing: error)
    }
  }

  func save() {
    do {
      try TaggerStore.saveConfig(config, to: configURL)
      lastErrorMessage = nil
    } catch {
      lastErrorMessage = String(describing: error)
    }
  }

  func pickAndAddRoots() {
    let panel = NSOpenPanel()
    panel.title = "Choose root directories"
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = true
    panel.canCreateDirectories = false

    guard panel.runModal() == .OK else { return }
    let selected = panel.urls.map(\.path)
    let merged = Array(Set(config.roots + selected)).sorted()
    config.roots = merged
  }

  func removeRoot(at index: Int) {
    guard config.roots.indices.contains(index) else { return }
    config.roots.remove(at: index)
  }

  func runNow() async {
    manualScanInProgress = true
    isRunning = true
    lastRunLines = []
    lastRunErrors = []
    lastErrorMessage = nil
    scanProgress = nil
    defer {
      scanProgress = nil
      isRunning = false
      manualScanInProgress = false
    }

    let normalizedRoots = Array(
      Set(
        config.roots
          .map(normalizeInputPath)
          .filter { !$0.isEmpty }
          .map { URL(fileURLWithPath: $0).standardizedFileURL.path }
      )
    ).sorted()

    // Initialize results structure for each root
    var newResultsByRoot: [String: [String: FolderScanResult.Status]] = [:]
    for root in normalizedRoots {
      newResultsByRoot[root] = [:]
    }

    let concurrency = config.concurrency ?? Tagger.defaultConcurrency()
    let tagger = Tagger(config: config)

    let summary = await tagger.run(
      roots: normalizedRoots,
      concurrency: concurrency,
      onProgress: { @MainActor [weak self] progress in
        self?.scanProgress = progress
      },
      onResult: { @MainActor [weak self] result in
        guard let self = self else { return }
        self.folderResults[result.path] = result.status
        if let origin = result.origin {
          self.folderOrigins[result.path] = origin
        }

        // Find which root this result belongs to
        for root in normalizedRoots {
          if pathIsAtOrUnderRoot(result.path, root: root) {
            newResultsByRoot[root]?[result.path] = result.status
            self.resultsByRoot[root] = newResultsByRoot[root]
            break
          }
        }
      }
    )

    // Final update
    resultsByRoot = newResultsByRoot

    lastRunLines = summary.lines
    lastRunErrors = summary.errors
    let finishedAt = Date()
    lastRunAt = finishedAt
    lastRunSource = .manual
    lastManualRunAt = finishedAt
    persistScanSnapshot(source: .manual, finishedAt: finishedAt, roots: normalizedRoots)
  }

  func refreshSchedulerStatus() {
    let status = LaunchdScheduler.status()
    schedulerInstalled = status.installed
    schedulerLoaded = status.loaded
    schedulerStartIntervalSeconds = status.startIntervalSeconds

    if !isRunning {
      loadScanHistoryFromDisk()
    }
  }

  var schedulerNeedsReinstall: Bool {
    guard schedulerInstalled && schedulerLoaded else { return false }
    let desiredSeconds = max(60, config.scheduleSeconds ?? TaggerDefaults.scheduleSeconds)
    guard let installedSeconds = schedulerStartIntervalSeconds else { return true }
    return installedSeconds != desiredSeconds
  }

  func installOrUpdateScheduler() async {
    save()

    let seconds = max(60, config.scheduleSeconds ?? TaggerDefaults.scheduleSeconds)
    do {
      try await Task.detached {
        try LaunchdScheduler.install(startIntervalSeconds: seconds)
      }.value
      refreshSchedulerStatus()
      lastErrorMessage = nil
    } catch {
      refreshSchedulerStatus()
      lastErrorMessage = String(describing: error)
    }
  }

  func reinstallScheduler() async {
    save()

    let seconds = max(60, config.scheduleSeconds ?? TaggerDefaults.scheduleSeconds)
    do {
      try await Task.detached {
        try LaunchdScheduler.uninstall()
        try LaunchdScheduler.install(startIntervalSeconds: seconds)
      }.value
      refreshSchedulerStatus()
      lastErrorMessage = nil
    } catch {
      refreshSchedulerStatus()
      lastErrorMessage = String(describing: error)
    }
  }

  func uninstallScheduler() async {
    do {
      try await Task.detached {
        try LaunchdScheduler.uninstall()
      }.value
      refreshSchedulerStatus()
      lastErrorMessage = nil
    } catch {
      refreshSchedulerStatus()
      lastErrorMessage = String(describing: error)
    }
  }

  func runScheduledNow() async {
    do {
      try await Task.detached {
        try LaunchdScheduler.runNow()
      }.value
      refreshSchedulerStatus()
      lastErrorMessage = nil
    } catch {
      refreshSchedulerStatus()
      lastErrorMessage = String(describing: error)
    }
  }

  // MARK: - Persistence

  private func loadScanHistoryFromDisk() {
    guard let history = ScanHistoryStore.load(from: TaggerPaths.scanHistoryURL()) else { return }

    lastScheduledRunAt = history.lastScheduled?.finishedAt
    lastManualRunAt = history.lastManual?.finishedAt

    guard let snapshot = history.last else { return }
    applyScanSnapshot(snapshot)
  }

  private func applyScanSnapshot(_ snapshot: ScanSnapshot) {
    lastRunAt = snapshot.finishedAt
    lastRunSource = snapshot.source
    lastRunLines = snapshot.lines
    lastRunErrors = snapshot.errors

    folderOrigins = snapshot.origins

    let restoredResultsByRoot = snapshot.resultsByRoot.mapValues { results in
      results.mapValues { $0.toStatus() }
    }
    resultsByRoot = restoredResultsByRoot

    var flattened: [String: FolderScanResult.Status] = [:]
    for (_, results) in restoredResultsByRoot {
      for (path, status) in results {
        flattened[path] = status
      }
    }
    folderResults = flattened
  }

  private func persistScanSnapshot(source: ScanSource, finishedAt: Date, roots: [String]) {
    let persistedResultsByRoot = resultsByRoot.mapValues { results in
      results.mapValues { PersistedFolderStatus(from: $0) }
    }

    let snapshot = ScanSnapshot(
      source: source,
      finishedAt: finishedAt,
      roots: roots,
      resultsByRoot: persistedResultsByRoot,
      origins: folderOrigins,
      lines: lastRunLines,
      errors: lastRunErrors
    )

    do {
      let history = try ScanHistoryStore.update(with: snapshot, url: TaggerPaths.scanHistoryURL())
      lastScheduledRunAt = history.lastScheduled?.finishedAt
      lastManualRunAt = history.lastManual?.finishedAt
    } catch {
      lastErrorMessage = String(describing: error)
    }
  }

  // MARK: - Status Summary

  func statusSummary(for root: String) -> RootStatusSummary {
    let normalizedRoot = URL(fileURLWithPath: normalizeInputPath(root)).standardizedFileURL.path
    guard let results = resultsByRoot[normalizedRoot] else {
      return RootStatusSummary()
    }

    var summary = RootStatusSummary()
    for (_, status) in results {
      switch status {
      case .synced: summary.synced += 1
      case .localChanges: summary.localChanges += 1
      case .localOnly: summary.localOnly += 1
      case .noGit: summary.noGit += 1
      case .file: summary.files += 1
      case .error: summary.errors += 1
      }
    }
    summary.total = results.count
    return summary
  }

  func childFolders(for root: String) -> [(path: String, status: FolderScanResult.Status, origin: String?)] {
    let normalizedRoot = URL(fileURLWithPath: normalizeInputPath(root)).standardizedFileURL.path
    guard let results = resultsByRoot[normalizedRoot] else {
      return []
    }
    return results.map { (path: $0.key, status: $0.value, origin: folderOrigins[$0.key]) }.sorted { $0.path < $1.path }
  }

  // MARK: - Helpers

  private static func defaultConfigURL() -> URL {
    TaggerPaths.configURL()
  }

  private static func loadConfig(from url: URL) throws -> TaggerConfig {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(TaggerConfig.self, from: data)
  }

  private static func saveConfig(_ config: TaggerConfig, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(config)
    try data.write(to: url, options: [.atomic])
  }

  // MARK: - File Watching

  private func setupAppSupportWatcher() {
    let dirURL = TaggerPaths.applicationSupportDirectoryURL()
    try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

    let watcher = DirectoryWatcher(directoryURL: dirURL) {
      Task { @MainActor in
        TaggerStore.shared.scheduleAppSupportSync()
      }
    }
    try? watcher.start()
    appSupportWatcher = watcher
  }

  private func scheduleAppSupportSync() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      guard appSupportSyncWorkItem == nil else { return }

      let item = DispatchWorkItem { [weak self] in
        guard let self else { return }
        self.appSupportSyncWorkItem = nil
        self.handleAppSupportDirectoryChange()
      }
      appSupportSyncWorkItem = item
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: item)
    }
  }

  private func handleAppSupportDirectoryChange() {
    guard !manualScanInProgress else { return }

    syncScheduledProgressFromDisk()

    if !isRunning {
      loadScanHistoryFromDisk()
    }
  }

  private func syncScheduledProgressFromDisk() {
    guard !manualScanInProgress else { return }

    let url = TaggerPaths.scanProgressURL()
    if let file = ScanProgressStore.load(from: url), file.source == .scheduled {
      let age = Date().timeIntervalSince(file.updatedAt)
      if age > 300 {
        try? ScanProgressStore.clear(at: url)
        isRunning = false
        scanProgress = nil
        return
      }

      isRunning = true
      scanProgress = file.toScanProgress()
      return
    }

    if isRunning {
      isRunning = false
    }
    scanProgress = nil
  }
}

func normalizeInputPath(_ value: String) -> String {
  var input = value.trimmingCharacters(in: .whitespacesAndNewlines)
  if (input.hasPrefix("\"") && input.hasSuffix("\"")) || (input.hasPrefix("'") && input.hasSuffix("'")) {
    input.removeFirst()
    input.removeLast()
  }
  if input == "~" {
    input = NSHomeDirectory()
  } else if input.hasPrefix("~/") {
    input = (NSHomeDirectory() as NSString).appendingPathComponent(String(input.dropFirst(2)))
  }
  return input
}
