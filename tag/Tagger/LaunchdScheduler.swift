import Darwin
import Foundation

struct LaunchdStatus: Sendable {
  var label: String
  var plistURL: URL
  var installed: Bool
  var loaded: Bool
  var startIntervalSeconds: Int?
}

enum LaunchdSchedulerError: Error, CustomStringConvertible {
  case missingExecutableURL
  case invalidInterval(Int)

  var description: String {
    switch self {
    case .missingExecutableURL:
      return "Could not locate app executable path."
    case let .invalidInterval(value):
      return "Invalid schedule interval: \(value)"
    }
  }
}

enum LaunchdScheduler {
  static func status(runner: ProcessRunner = ProcessRunner()) -> LaunchdStatus {
    let label = TaggerPaths.launchAgentLabel()
    let plistURL = TaggerPaths.launchAgentPlistURL()

    let installed = FileManager.default.fileExists(atPath: plistURL.path)
    let loaded = (try? isLoaded(label: label, runner: runner)) ?? false
    let startIntervalSeconds = installed ? readStartIntervalSeconds(plistURL: plistURL) : nil
    return LaunchdStatus(
      label: label,
      plistURL: plistURL,
      installed: installed,
      loaded: loaded,
      startIntervalSeconds: startIntervalSeconds
    )
  }

  static func install(startIntervalSeconds: Int, runner: ProcessRunner = ProcessRunner()) throws {
    guard startIntervalSeconds >= 60 else {
      throw LaunchdSchedulerError.invalidInterval(startIntervalSeconds)
    }

    guard let executableURL = Bundle.main.executableURL else {
      throw LaunchdSchedulerError.missingExecutableURL
    }

    let label = TaggerPaths.launchAgentLabel()
    let plistURL = TaggerPaths.launchAgentPlistURL()

    try FileManager.default.createDirectory(at: TaggerPaths.launchAgentsDirectoryURL(), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: TaggerPaths.logsDirectoryURL(), withIntermediateDirectories: true)

    let stdoutPath = TaggerPaths.schedulerOutLogURL().path
    let stderrPath = TaggerPaths.schedulerErrLogURL().path

    let plist: [String: Any] = [
      "Label": label,
      "ProgramArguments": [
        executableURL.path,
        "--run-once",
      ],
      "RunAtLoad": true,
      "StartInterval": startIntervalSeconds,
      "StandardOutPath": stdoutPath,
      "StandardErrorPath": stderrPath,
    ]

    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try data.write(to: plistURL, options: [.atomic])

    // Reload to pick up updates.
    try? bootout(plistURL: plistURL, runner: runner)
    try bootstrap(plistURL: plistURL, runner: runner)
    try? kickstart(label: label, runner: runner)
  }

  static func uninstall(runner: ProcessRunner = ProcessRunner()) throws {
    let plistURL = TaggerPaths.launchAgentPlistURL()
    try? bootout(plistURL: plistURL, runner: runner)
    if FileManager.default.fileExists(atPath: plistURL.path) {
      try FileManager.default.removeItem(at: plistURL)
    }
  }

  static func runNow(runner: ProcessRunner = ProcessRunner()) throws {
    let label = TaggerPaths.launchAgentLabel()
    try kickstart(label: label, runner: runner)
  }

  // MARK: - launchctl

  private static func domain() -> String {
    "gui/\(getuid())"
  }

  private static func readStartIntervalSeconds(plistURL: URL) -> Int? {
    guard let data = try? Data(contentsOf: plistURL) else { return nil }
    guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else { return nil }
    guard let dict = plist as? [String: Any] else { return nil }
    if let value = dict["StartInterval"] as? Int { return value }
    if let value = dict["StartInterval"] as? NSNumber { return value.intValue }
    return nil
  }

  private static func isLoaded(label: String, runner: ProcessRunner) throws -> Bool {
    let result = try runner.run("launchctl", ["print", "\(domain())/\(label)"], cwd: nil)
    return result.exitCode == 0
  }

  private static func bootstrap(plistURL: URL, runner: ProcessRunner) throws {
    let result = try runner.run("launchctl", ["bootstrap", domain(), plistURL.path], cwd: nil)
    guard result.exitCode == 0 else {
      throw CmdError.failed(cmd: "launchctl", args: ["bootstrap", domain(), plistURL.path], cwd: nil, exitCode: result.exitCode, stderr: result.stderr)
    }
  }

  private static func bootout(plistURL: URL, runner: ProcessRunner) throws {
    let result = try runner.run("launchctl", ["bootout", domain(), plistURL.path], cwd: nil)
    guard result.exitCode == 0 else {
      throw CmdError.failed(cmd: "launchctl", args: ["bootout", domain(), plistURL.path], cwd: nil, exitCode: result.exitCode, stderr: result.stderr)
    }
  }

  private static func kickstart(label: String, runner: ProcessRunner) throws {
    let result = try runner.run("launchctl", ["kickstart", "-k", "\(domain())/\(label)"], cwd: nil)
    guard result.exitCode == 0 else {
      throw CmdError.failed(cmd: "launchctl", args: ["kickstart", "-k", "\(domain())/\(label)"], cwd: nil, exitCode: result.exitCode, stderr: result.stderr)
    }
  }
}
