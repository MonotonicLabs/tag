import Foundation

enum ScanSource: String, Codable, Sendable {
  case manual
  case scheduled
}

struct PersistedFolderStatus: Codable, Hashable, Sendable {
  enum Kind: String, Codable, Sendable {
    case synced
    case localChanges
    case localOnly
    case noGit
    case multipleGitRepos
    case file
    case error
  }

  var kind: Kind
  var errorMessage: String?

  init(kind: Kind, errorMessage: String? = nil) {
    self.kind = kind
    self.errorMessage = errorMessage
  }

  init(from status: FolderScanResult.Status) {
    switch status {
    case .synced:
      self.init(kind: .synced)
    case .localChanges:
      self.init(kind: .localChanges)
    case .localOnly:
      self.init(kind: .localOnly)
    case .noGit:
      self.init(kind: .noGit)
    case .multipleGitRepos:
      self.init(kind: .multipleGitRepos)
    case .file:
      self.init(kind: .file)
    case let .error(message):
      self.init(kind: .error, errorMessage: message)
    }
  }

  func toStatus() -> FolderScanResult.Status {
    switch kind {
    case .synced:
      return .synced
    case .localChanges:
      return .localChanges
    case .localOnly:
      return .localOnly
    case .noGit:
      return .noGit
    case .multipleGitRepos:
      return .multipleGitRepos
    case .file:
      return .file
    case .error:
      return .error(errorMessage ?? "Unknown error")
    }
  }
}

struct ScanSnapshot: Codable, Hashable, Sendable {
  var source: ScanSource
  var finishedAt: Date
  var roots: [String]
  var resultsByRoot: [String: [String: PersistedFolderStatus]]
  var origins: [String: String]
  var lines: [String]
  var errors: [String]
}

struct ScanHistoryFile: Codable, Hashable, Sendable {
  var version: Int
  var last: ScanSnapshot?
  var lastManual: ScanSnapshot?
  var lastScheduled: ScanSnapshot?

  init(version: Int = 1, last: ScanSnapshot? = nil, lastManual: ScanSnapshot? = nil, lastScheduled: ScanSnapshot? = nil) {
    self.version = version
    self.last = last
    self.lastManual = lastManual
    self.lastScheduled = lastScheduled
  }
}

enum ScanHistoryStore {
  static func load(from url: URL) -> ScanHistoryFile? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? decoder().decode(ScanHistoryFile.self, from: data)
  }

  static func save(_ history: ScanHistoryFile, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try encoder().encode(history)
    try data.write(to: url, options: [.atomic])
  }

  static func update(with snapshot: ScanSnapshot, url: URL) throws -> ScanHistoryFile {
    var history = load(from: url) ?? ScanHistoryFile()
    history.last = snapshot
    switch snapshot.source {
    case .manual:
      history.lastManual = snapshot
    case .scheduled:
      history.lastScheduled = snapshot
    }
    try save(history, to: url)
    return history
  }

  private static func encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }

  private static func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}
