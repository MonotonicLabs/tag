import Foundation
import XCTest

@testable import tag

final class TaggerCollectTasksTests: XCTestCase {
  func testEmptyNonRepoChildIsScannedAsNoGitCandidate() async throws {
    let root = try makeTempRoot()
    let empty = try createDirectory("empty", under: root)

    let collected = await Tagger(config: .default).collectTasks(roots: [root.path])

    XCTAssertEqual(collected.errors, [])
    XCTAssertEqual(collected.tasks.map(\.fullPath), [empty.path])
    XCTAssertEqual(collected.tasks.map(\.displayPath), ["empty"])
    XCTAssertEqual(collected.tasks.map(\.kind), [.dir])
  }

  func testNonRepoChildWithOnlyNonRepoSubfoldersIsScannedAsNoGitCandidate() async throws {
    let root = try makeTempRoot()
    let group = try createDirectory("group", under: root)
    _ = try createDirectory("group", "plain", under: root)

    let collected = await Tagger(config: .default).collectTasks(roots: [root.path])

    XCTAssertEqual(collected.errors, [])
    XCTAssertEqual(collected.tasks.map(\.fullPath), [group.path])
    XCTAssertEqual(collected.tasks.map(\.displayPath), ["group"])
    XCTAssertEqual(collected.tasks.map(\.kind), [.dir])
  }

  func testNonRepoChildWithGitRepoSubfolderScansGroupAndImmediateSubfolders() async throws {
    let root = try makeTempRoot()
    let group = try createDirectory("m5", under: root)
    let plain = try createDirectory("m5", "plain", under: root)
    let repo = try createDirectory("m5", "repo", under: root)
    try markGitRepo(repo)

    let collected = await Tagger(config: .default).collectTasks(roots: [root.path])

    XCTAssertEqual(collected.errors, [])
    XCTAssertEqual(collected.tasks.map(\.fullPath), [group.path, plain.path, repo.path])
    XCTAssertEqual(collected.tasks.map(\.displayPath), ["m5", "m5/plain", "m5/repo"])
    XCTAssertEqual(collected.tasks.map(\.kind), [.gitRepoGroup, .dir, .dir])
  }

  func testDirectGitRepoChildIsScannedWithoutExpandingChildren() async throws {
    let root = try makeTempRoot()
    let repo = try createDirectory("repo", under: root)
    try markGitRepo(repo)
    _ = try createDirectory("repo", "nested", under: root)

    let collected = await Tagger(config: .default).collectTasks(roots: [root.path])

    XCTAssertEqual(collected.errors, [])
    XCTAssertEqual(collected.tasks.map(\.fullPath), [repo.path])
    XCTAssertEqual(collected.tasks.map(\.displayPath), ["repo"])
    XCTAssertEqual(collected.tasks.map(\.kind), [.dir])
  }

  private func makeTempRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("tag-collect-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: root)
    }
    return root
  }

  @discardableResult
  private func createDirectory(_ components: String..., under root: URL) throws -> URL {
    var url = root
    for component in components {
      url.appendPathComponent(component, isDirectory: true)
    }
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func markGitRepo(_ repo: URL) throws {
    try FileManager.default.createDirectory(
      at: repo.appendingPathComponent(".git", isDirectory: true),
      withIntermediateDirectories: true
    )
  }
}
