import Foundation

enum FinderMetadataCleaner {
  struct ClearSummary: Sendable {
    var attemptedPaths: Int
    var clearedPaths: Int
    var errors: [String]
  }

  static func clearTagsAndCommentsForFolderAndTopLevelItems(atPath directoryPath: String) throws -> ClearSummary {
    var isDir = ObjCBool(false)
    guard FileManager.default.fileExists(atPath: directoryPath, isDirectory: &isDir), isDir.boolValue else {
      throw NSError(domain: "tag", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not a directory: \(directoryPath)"])
    }

    let entries = try FileManager.default.contentsOfDirectory(atPath: directoryPath)
    var summary = ClearSummary(attemptedPaths: 0, clearedPaths: 0, errors: [])
    let runner = ProcessRunner()

    let allPaths = [directoryPath] + entries.map { (directoryPath as NSString).appendingPathComponent($0) }

    for fullPath in allPaths {
      summary.attemptedPaths += 1
      var pathErrors: [String] = []

      do {
        try FinderTagging.clearAllTagsAndLabel(atPath: fullPath)
      } catch {
        pathErrors.append("Failed to clear tags for \(fullPath): \(error)")
      }

      do {
        try FinderComment.clearFinderComment(atPath: fullPath, runner: runner)
      } catch {
        pathErrors.append("Failed to clear comment for \(fullPath): \(error)")
      }

      if pathErrors.isEmpty {
        summary.clearedPaths += 1
      } else {
        summary.errors.append(contentsOf: pathErrors)
      }
    }

    return summary
  }
}
