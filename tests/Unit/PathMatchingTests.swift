import XCTest

@testable import tag

final class PathMatchingTests: XCTestCase {
  func testMatchesExactRoot() {
    XCTAssertTrue(pathIsAtOrUnderRoot("/tmp/root", root: "/tmp/root"))
  }

  func testMatchesChildPath() {
    XCTAssertTrue(pathIsAtOrUnderRoot("/tmp/root/child", root: "/tmp/root"))
  }

  func testDoesNotMatchPrefixCollision() {
    XCTAssertFalse(pathIsAtOrUnderRoot("/tmp/root2/child", root: "/tmp/root"))
  }

  func testHandlesTrailingSlashRoot() {
    XCTAssertTrue(pathIsAtOrUnderRoot("/tmp/root/child", root: "/tmp/root/"))
  }

  func testRootSlashMatchesAllAbsolutePaths() {
    XCTAssertTrue(pathIsAtOrUnderRoot("/tmp/root", root: "/"))
  }
}

