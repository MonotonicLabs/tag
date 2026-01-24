import Foundation

enum TaggerPaths {
  static func bundleIdentifier() -> String {
    Bundle.main.bundleIdentifier ?? "tag"
  }

  static func applicationSupportDirectoryURL() -> URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return base.appendingPathComponent(bundleIdentifier(), isDirectory: true)
  }

  static func configURL() -> URL {
    applicationSupportDirectoryURL().appendingPathComponent("config.json")
  }

  static func scanHistoryURL() -> URL {
    applicationSupportDirectoryURL().appendingPathComponent("scan-history.json")
  }

  static func scanProgressURL() -> URL {
    applicationSupportDirectoryURL().appendingPathComponent("scan-progress.json")
  }

  static func logsDirectoryURL() -> URL {
    let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
    return base
      .appendingPathComponent("Logs", isDirectory: true)
      .appendingPathComponent(bundleIdentifier(), isDirectory: true)
  }

  static func schedulerOutLogURL() -> URL {
    logsDirectoryURL().appendingPathComponent("scheduler.out.log")
  }

  static func schedulerErrLogURL() -> URL {
    logsDirectoryURL().appendingPathComponent("scheduler.err.log")
  }

  static func launchAgentsDirectoryURL() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library", isDirectory: true)
      .appendingPathComponent("LaunchAgents", isDirectory: true)
  }

  static func launchAgentLabel() -> String {
    "\(bundleIdentifier()).scheduler"
  }

  static func launchAgentPlistURL() -> URL {
    launchAgentsDirectoryURL().appendingPathComponent("\(launchAgentLabel()).plist")
  }
}
