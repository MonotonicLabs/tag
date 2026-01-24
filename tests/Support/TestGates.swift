import XCTest

enum TestGates {
  static func requireIntegrationTestsEnabled(file: StaticString = #filePath, line: UInt = #line) throws {
    let enabled = ProcessInfo.processInfo.environment["TAG_INTEGRATION_TESTS"] == "1"
    try XCTSkipUnless(
      enabled,
      "Run the tagIntegration scheme (or set TAG_INTEGRATION_TESTS=1) to enable integration tests.",
      file: file,
      line: line
    )
  }
}
