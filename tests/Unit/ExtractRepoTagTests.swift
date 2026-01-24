import XCTest

@testable import tag

final class ExtractRepoTagTests: XCTestCase {
  func testParsesSshStyleOrigin() {
    XCTAssertEqual(extractRepoTag(from: "git@github.com:owner/repo.git"), "owner/repo")
  }

  func testParsesHttpsOriginWithDotGit() {
    XCTAssertEqual(extractRepoTag(from: "https://github.com/owner/repo.git"), "owner/repo")
  }

  func testParsesHttpsOriginWithoutDotGit() {
    XCTAssertEqual(extractRepoTag(from: "https://github.com/owner/repo"), "owner/repo")
  }

  func testTrimsWhitespace() {
    XCTAssertEqual(extractRepoTag(from: "  https://github.com/owner/repo.git  "), "owner/repo")
  }

  func testRejectsEmptyOrGarbage() {
    XCTAssertNil(extractRepoTag(from: ""))
    XCTAssertNil(extractRepoTag(from: "not a url"))
  }
}

