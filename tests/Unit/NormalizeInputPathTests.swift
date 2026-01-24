import Foundation
import XCTest

@testable import tag

final class NormalizeInputPathTests: XCTestCase {
  func testTrimsWhitespaceAndNewlines() {
    XCTAssertEqual(normalizeInputPath("  /tmp  "), "/tmp")
    XCTAssertEqual(normalizeInputPath("\n/tmp\n"), "/tmp")
  }

  func testStripsSurroundingDoubleQuotes() {
    XCTAssertEqual(normalizeInputPath("\"/tmp\""), "/tmp")
  }

  func testStripsSurroundingSingleQuotes() {
    XCTAssertEqual(normalizeInputPath("'/tmp'"), "/tmp")
  }

  func testExpandsHomeTilde() {
    XCTAssertEqual(normalizeInputPath("~"), NSHomeDirectory())
  }

  func testExpandsHomeTildeSubpath() {
    let expected = (NSHomeDirectory() as NSString).appendingPathComponent("projects")
    XCTAssertEqual(normalizeInputPath("~/projects"), expected)
  }

  func testDoesNotExpandNonHomeTildePrefix() {
    XCTAssertEqual(normalizeInputPath("~someone/projects"), "~someone/projects")
  }
}

