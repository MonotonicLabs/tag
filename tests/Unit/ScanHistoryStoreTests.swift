import Foundation
import XCTest

@testable import tag

final class ScanHistoryStoreTests: XCTestCase {
  func testUpdateStoresLastAndLastManual() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
      .appendingPathComponent("scan-history.json")

    let finishedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let snapshot = ScanSnapshot(
      source: .manual,
      finishedAt: finishedAt,
      roots: ["/tmp"],
      resultsByRoot: ["/tmp": ["/tmp/repo": PersistedFolderStatus(kind: .synced)]],
      origins: ["/tmp/repo": "owner/repo"],
      lines: ["Tagged repo"],
      errors: []
    )

    let history = try ScanHistoryStore.update(with: snapshot, url: url)
    XCTAssertEqual(history.last?.source, .manual)
    XCTAssertEqual(history.lastManual?.source, .manual)
    XCTAssertNil(history.lastScheduled)

    let loaded = ScanHistoryStore.load(from: url)
    XCTAssertEqual(loaded?.last?.source, .manual)
    XCTAssertEqual(loaded?.lastManual?.source, .manual)
    XCTAssertNil(loaded?.lastScheduled)
  }

  func testUpdateStoresLastAndLastScheduledWithoutDeletingLastManual() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
      .appendingPathComponent("scan-history.json")

    let manual = ScanSnapshot(
      source: .manual,
      finishedAt: Date(timeIntervalSince1970: 1_700_000_000),
      roots: ["/tmp"],
      resultsByRoot: ["/tmp": ["/tmp/repo": PersistedFolderStatus(kind: .synced)]],
      origins: [:],
      lines: [],
      errors: []
    )
    _ = try ScanHistoryStore.update(with: manual, url: url)

    let scheduled = ScanSnapshot(
      source: .scheduled,
      finishedAt: Date(timeIntervalSince1970: 1_700_000_100),
      roots: ["/tmp"],
      resultsByRoot: ["/tmp": ["/tmp/repo": PersistedFolderStatus(kind: .localChanges)]],
      origins: [:],
      lines: [],
      errors: []
    )
    _ = try ScanHistoryStore.update(with: scheduled, url: url)

    let loaded = ScanHistoryStore.load(from: url)
    XCTAssertEqual(loaded?.last?.source, .scheduled)
    XCTAssertEqual(loaded?.lastManual?.source, .manual)
    XCTAssertEqual(loaded?.lastScheduled?.source, .scheduled)
  }
}

