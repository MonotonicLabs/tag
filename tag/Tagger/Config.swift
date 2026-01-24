import Foundation

enum TaggerDefaults {
  static let scheduleSeconds: Int = 300
}

struct TagDefinition: Codable, Hashable, Sendable {
  var name: String
  var colorIndex: Int
  var enabled: Bool

  init(name: String, colorIndex: Int, enabled: Bool = true) {
    self.name = name
    self.colorIndex = colorIndex
    self.enabled = enabled
  }

  enum CodingKeys: String, CodingKey {
    case name
    case colorIndex
    case enabled
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.name = try container.decode(String.self, forKey: .name)
    self.colorIndex = try container.decode(Int.self, forKey: .colorIndex)
    self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(colorIndex, forKey: .colorIndex)
    try container.encode(enabled, forKey: .enabled)
  }
}

struct StatusTags: Codable, Hashable, Sendable {
  var localGitOnly: TagDefinition
  var gitSynced: TagDefinition
  var unexpectedFile: TagDefinition
  var noGitRepo: TagDefinition
  var gitLocalChanges: TagDefinition

  init(
    localGitOnly: TagDefinition,
    gitSynced: TagDefinition,
    unexpectedFile: TagDefinition,
    noGitRepo: TagDefinition,
    gitLocalChanges: TagDefinition
  ) {
    self.localGitOnly = localGitOnly
    self.gitSynced = gitSynced
    self.unexpectedFile = unexpectedFile
    self.noGitRepo = noGitRepo
    self.gitLocalChanges = gitLocalChanges
  }
}

struct TaggerConfig: Codable, Hashable, Sendable {
  var roots: [String]
  var tags: StatusTags
  var concurrency: Int?
  var scheduleSeconds: Int?
  var writeFinderComment: Bool

  init(
    roots: [String],
    tags: StatusTags,
    concurrency: Int? = nil,
    scheduleSeconds: Int? = nil,
    writeFinderComment: Bool = true
  ) {
    self.roots = roots
    self.tags = tags
    self.concurrency = concurrency
    self.scheduleSeconds = scheduleSeconds
    self.writeFinderComment = writeFinderComment
  }
}

extension TaggerConfig {
  static let `default` = TaggerConfig(
    roots: [],
    tags: StatusTags(
      localGitOnly: TagDefinition(name: "Local Git Only", colorIndex: 1),
      gitSynced: TagDefinition(name: "Git Synced", colorIndex: 2),
      unexpectedFile: TagDefinition(name: "Unexpected File", colorIndex: 5, enabled: false),
      noGitRepo: TagDefinition(name: "No Git Repo", colorIndex: 6),
      gitLocalChanges: TagDefinition(name: "Git Local Changes", colorIndex: 7)
    ),
    concurrency: nil,
    scheduleSeconds: TaggerDefaults.scheduleSeconds,
    writeFinderComment: true
  )
}
