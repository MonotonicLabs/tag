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

enum FinderComment {
  static let finderCommentAttr = "com.apple.metadata:kMDItemFinderComment"

  static func setFinderCommentUsingFinder(atPath path: String, comment: String, runner: ProcessRunner) throws {
    let normalized = comment.trimmingCharacters(in: .whitespacesAndNewlines)
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

  static func clearFinderCommentXattr(atPath path: String) throws {
    try Xattr.remove(name: finderCommentAttr, atPath: path)
  }

  static func clearFinderComment(atPath path: String, runner: ProcessRunner) throws {
    try setFinderCommentUsingFinder(atPath: path, comment: "", runner: runner)
    try clearFinderCommentXattr(atPath: path)
  }
}

actor FinderCommentWriter {
  private let runner: ProcessRunner

  init(runner: ProcessRunner) {
    self.runner = runner
  }

  func setFinderComment(atPath path: String, comment: String) throws {
    try FinderComment.setFinderCommentUsingFinder(atPath: path, comment: comment, runner: runner)
  }
}
