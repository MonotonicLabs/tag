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
  static let defaultMultipleGitRepos = TagDefinition(name: "Multiple Git Repos", colorIndex: 3)

  var localGitOnly: TagDefinition
  var gitSynced: TagDefinition
  var unexpectedFile: TagDefinition
  var noGitRepo: TagDefinition
  var gitLocalChanges: TagDefinition
  var multipleGitRepos: TagDefinition

  init(
    localGitOnly: TagDefinition,
    gitSynced: TagDefinition,
    unexpectedFile: TagDefinition,
    noGitRepo: TagDefinition,
    gitLocalChanges: TagDefinition,
    multipleGitRepos: TagDefinition = StatusTags.defaultMultipleGitRepos
  ) {
    self.localGitOnly = localGitOnly
    self.gitSynced = gitSynced
    self.unexpectedFile = unexpectedFile
    self.noGitRepo = noGitRepo
    self.gitLocalChanges = gitLocalChanges
    self.multipleGitRepos = multipleGitRepos
  }

  enum CodingKeys: String, CodingKey {
    case localGitOnly
    case gitSynced
    case unexpectedFile
    case noGitRepo
    case gitLocalChanges
    case multipleGitRepos
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.localGitOnly = try container.decode(TagDefinition.self, forKey: .localGitOnly)
    self.gitSynced = try container.decode(TagDefinition.self, forKey: .gitSynced)
    self.unexpectedFile = try container.decode(TagDefinition.self, forKey: .unexpectedFile)
    self.noGitRepo = try container.decode(TagDefinition.self, forKey: .noGitRepo)
    self.gitLocalChanges = try container.decode(TagDefinition.self, forKey: .gitLocalChanges)
    self.multipleGitRepos =
      try container.decodeIfPresent(TagDefinition.self, forKey: .multipleGitRepos) ?? Self.defaultMultipleGitRepos
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(localGitOnly, forKey: .localGitOnly)
    try container.encode(gitSynced, forKey: .gitSynced)
    try container.encode(unexpectedFile, forKey: .unexpectedFile)
    try container.encode(noGitRepo, forKey: .noGitRepo)
    try container.encode(gitLocalChanges, forKey: .gitLocalChanges)
    try container.encode(multipleGitRepos, forKey: .multipleGitRepos)
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
      gitLocalChanges: TagDefinition(name: "Git Local Changes", colorIndex: 7),
      multipleGitRepos: StatusTags.defaultMultipleGitRepos
    ),
    concurrency: nil,
    scheduleSeconds: TaggerDefaults.scheduleSeconds,
    writeFinderComment: true
  )
}
