import XCTest

@testable import tag

final class TagDefinitionCodableTests: XCTestCase {
  func testEnabledDefaultsToTrueWhenOmitted() throws {
    let data = #"{"name":"Example","colorIndex":3}"#.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(TagDefinition.self, from: data)
    XCTAssertTrue(decoded.enabled)
  }

  func testEnabledDecodesWhenPresent() throws {
    let data = #"{"name":"Example","colorIndex":3,"enabled":false}"#.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(TagDefinition.self, from: data)
    XCTAssertFalse(decoded.enabled)
  }
}

