import Foundation
import XCTest

@testable import tag

final class GitIntegrationTests: XCTestCase {
  func testStatusSummaryWithUpstreamAndNoChangesIsClean() throws {
    try TestGates.requireIntegrationTestsEnabled()

    let (repoURL, _, _, runner) = try makeRepoWithUpstream()
    let summary = Git.statusSummary(atPath: repoURL.path, runner: runner)
    XCTAssertEqual(summary, GitStatusSummary(hasUncommitted: false, hasUnpushed: false))
  }

  func testStatusSummaryDetectsAheadCommitsAsUnpushed() throws {
    try TestGates.requireIntegrationTestsEnabled()

    let (repoURL, _, fileURL, runner) = try makeRepoWithUpstream()
    try "change\n".data(using: .utf8)!.write(to: fileURL, options: [.atomic])
    try runGit(runner, ["add", fileURL.lastPathComponent], cwd: repoURL)
    try runGit(runner, ["commit", "--no-gpg-sign", "--no-verify", "-m", "ahead"], cwd: repoURL)

    let summary = Git.statusSummary(atPath: repoURL.path, runner: runner)
    XCTAssertEqual(summary, GitStatusSummary(hasUncommitted: false, hasUnpushed: true))
  }

  func testStatusSummaryDetectsUncommittedChanges() throws {
    try TestGates.requireIntegrationTestsEnabled()

    let (repoURL, _, fileURL, runner) = try makeRepoWithUpstream()
    try "uncommitted\n".data(using: .utf8)!.write(to: fileURL, options: [.atomic])

    let summary = Git.statusSummary(atPath: repoURL.path, runner: runner)
    XCTAssertEqual(summary, GitStatusSummary(hasUncommitted: true, hasUnpushed: false))
  }

  func testOriginUrlReadsConfiguredRemote() throws {
    try TestGates.requireIntegrationTestsEnabled()

    let (repoURL, originURL, _, runner) = try makeRepoWithUpstream()
    XCTAssertEqual(Git.originUrl(atPath: repoURL.path, runner: runner), originURL.path)
  }

  func testRunExpandsNonRepoChildWithGitRepoSubfolderAndTagsParentAsMultipleRepos() async throws {
    try TestGates.requireIntegrationTestsEnabled()

    let runner = ProcessRunner()
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("tag-tests-\(UUID().uuidString)", isDirectory: true)
    let group = root.appendingPathComponent("m5", isDirectory: true)
    let plain = group.appendingPathComponent("plain", isDirectory: true)
    let repo = group.appendingPathComponent("repo", isDirectory: true)

    try FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }

    try runGit(runner, ["init"], cwd: repo)

    _ = try await FinderTagging.setOrderedUserTags(
      atPath: group.path,
      tags: [TaggerConfig.default.tags.noGitRepo]
    )
    XCTAssertNotNil(try Xattr.get(name: FinderTagging.userTagsAttr, atPath: group.path))

    let config = TaggerConfig(
      roots: [],
      tags: TaggerConfig.default.tags,
      writeFinderComment: false
    )
    let recorder = FolderResultRecorder()

    let summary = await Tagger(config: config, runner: runner).run(
      roots: [root.path],
      concurrency: 1,
      onProgress: nil,
      onResult: { result in
        await recorder.record(result)
      }
    )
    let results = await recorder.results()

    XCTAssertEqual(summary.errors, [])
    XCTAssertTrue(summary.lines.contains("Tagged m5: Multiple Git Repos"))
    XCTAssertEqual(Set(results.map(\.path)), Set([group.path, plain.path, repo.path]))
    XCTAssertTrue(results.contains { $0.path == group.path && $0.status == .multipleGitRepos })

    let expectedTags = try FinderTagging.buildUserTagsPlistData(tags: [TaggerConfig.default.tags.multipleGitRepos])
    XCTAssertEqual(try Xattr.get(name: FinderTagging.userTagsAttr, atPath: group.path), expectedTags)
    XCTAssertEqual(try FinderTagging.getFinderLabelIndex(atPath: group.path), 3)
  }

  // MARK: - Helpers

  private actor FolderResultRecorder {
    private var values: [FolderScanResult] = []

    func record(_ result: FolderScanResult) {
      values.append(result)
    }

    func results() -> [FolderScanResult] {
      values
    }
  }

  private func makeRepoWithUpstream() throws -> (repoURL: URL, originURL: URL, fileURL: URL, runner: ProcessRunner) {
    let runner = ProcessRunner()

    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("tag-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }

    try runGit(runner, ["init", "--bare", "origin.git"], cwd: root)
    let originURL = root.appendingPathComponent("origin.git", isDirectory: true)

    let repoURL = root.appendingPathComponent("repo", isDirectory: true)
    try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)

    try runGit(runner, ["init", "-b", "main"], cwd: repoURL)
    try runGit(runner, ["config", "user.name", "Tag Tests"], cwd: repoURL)
    try runGit(runner, ["config", "user.email", "tests@localhost"], cwd: repoURL)

    let fileURL = repoURL.appendingPathComponent("README.md")
    try "hello\n".data(using: .utf8)!.write(to: fileURL, options: [.atomic])
    try runGit(runner, ["add", fileURL.lastPathComponent], cwd: repoURL)
    try runGit(runner, ["commit", "--no-gpg-sign", "--no-verify", "-m", "initial"], cwd: repoURL)

    try runGit(runner, ["remote", "add", "origin", originURL.path], cwd: repoURL)
    try runGit(runner, ["push", "--no-verify", "-u", "origin", "main"], cwd: repoURL)

    return (repoURL, originURL, fileURL, runner)
  }

  private func runGit(_ runner: ProcessRunner, _ args: [String], cwd: URL, file: StaticString = #filePath, line: UInt = #line)
    throws
  {
    let safeArgs = ["-c", "core.hooksPath=/dev/null"] + args
    let result = try runner.run("git", safeArgs, cwd: cwd)
    XCTAssertEqual(result.exitCode, 0, "git \(args.joined(separator: " ")) failed: \(result.stderr)", file: file, line: line)
    if result.exitCode != 0 {
      throw CmdError.failed(cmd: "git", args: args, cwd: cwd.path, exitCode: result.exitCode, stderr: result.stderr)
    }
  }
}
