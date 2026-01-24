import Foundation

enum ScanProgressPhase: String, Codable, Sendable {
  case preparing
  case running
}

struct ScanProgressFile: Codable, Sendable {
  var version: Int
  var source: ScanSource
  var phase: ScanProgressPhase
  var startedAt: Date
  var updatedAt: Date
  var total: Int?
  var completed: Int?
  var currentPath: String?

  init(
    version: Int = 1,
    source: ScanSource,
    phase: ScanProgressPhase,
    startedAt: Date,
    updatedAt: Date,
    total: Int? = nil,
    completed: Int? = nil,
    currentPath: String? = nil
  ) {
    self.version = version
    self.source = source
    self.phase = phase
    self.startedAt = startedAt
    self.updatedAt = updatedAt
    self.total = total
    self.completed = completed
    self.currentPath = currentPath
  }

  func toScanProgress() -> ScanProgress? {
    guard let total, let completed else { return nil }
    return ScanProgress(total: total, completed: completed, currentPath: currentPath)
  }
}

enum ScanProgressStore {
  static func load(from url: URL) -> ScanProgressFile? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? decoder().decode(ScanProgressFile.self, from: data)
  }

  static func save(_ progress: ScanProgressFile, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try encoder().encode(progress)
    try data.write(to: url, options: [.atomic])
  }

  static func clear(at url: URL) throws {
    if FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.removeItem(at: url)
    }
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

