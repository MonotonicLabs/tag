import Foundation

private let finderCommentAppleScript = """
on run argv
  set targetPath to item 1 of argv
  set commentText to item 2 of argv
  set targetAlias to POSIX file targetPath as alias
  tell application "Finder"
    set comment of targetAlias to commentText
  end tell
end run
"""

actor FinderCommentWriter {
  private let runner: ProcessRunner

  init(runner: ProcessRunner) {
    self.runner = runner
  }

  func setFinderComment(atPath path: String, comment: String) throws {
    let normalized = comment.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else { return }

    let result = try runner.run(
      "osascript",
      ["-e", finderCommentAppleScript, "--", path, normalized],
      cwd: nil
    )
    if result.exitCode != 0 {
      throw CmdError.failed(
        cmd: "osascript",
        args: ["-e", "<script>", "--", path, normalized],
        cwd: nil,
        exitCode: result.exitCode,
        stderr: result.stderr
      )
    }
  }
}

