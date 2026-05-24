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

  func testStatusTagsDefaultMultipleGitReposWhenOmitted() throws {
    let data = """
      {
        "localGitOnly": {"name":"Local Git Only","colorIndex":1,"enabled":true},
        "gitSynced": {"name":"Git Synced","colorIndex":2,"enabled":true},
        "unexpectedFile": {"name":"Unexpected File","colorIndex":5,"enabled":false},
        "noGitRepo": {"name":"No Git Repo","colorIndex":6,"enabled":true},
        "gitLocalChanges": {"name":"Git Local Changes","colorIndex":7,"enabled":true}
      }
      """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(StatusTags.self, from: data)
    XCTAssertEqual(decoded.multipleGitRepos, StatusTags.defaultMultipleGitRepos)
  }
}
