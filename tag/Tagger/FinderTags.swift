import Foundation

enum FinderTagging {
  static let finderInfoAttr = "com.apple.FinderInfo"
  static let userTagsAttr = "com.apple.metadata:_kMDItemUserTags"

  private static let finderLabelMask: UInt16 = 0x0e

  static func getFinderLabelIndex(atPath path: String) throws -> Int {
    guard let data = try Xattr.get(name: finderInfoAttr, atPath: path) else { return 0 }
    guard data.count == 32 else { return 0 }
    let bytes = [UInt8](data)
    let flags = (UInt16(bytes[8]) << 8) | UInt16(bytes[9])
    return Int((flags & finderLabelMask) >> 1)
  }

  static func setFinderLabelIndex(atPath path: String, colorIndex: Int) throws {
    let clamped = max(0, min(7, colorIndex))
    guard var data = try Xattr.get(name: finderInfoAttr, atPath: path) else {
      if clamped == 0 { return }
      var blank = [UInt8](repeating: 0, count: 32)
      let flags = UInt16((clamped << 1)) & finderLabelMask
      blank[8] = UInt8((flags >> 8) & 0xff)
      blank[9] = UInt8(flags & 0xff)
      try Xattr.set(name: finderInfoAttr, value: Data(blank), atPath: path)
      return
    }

    guard data.count == 32 else { return }

    var bytes = [UInt8](data)
    var flags = (UInt16(bytes[8]) << 8) | UInt16(bytes[9])
    flags = (flags & ~finderLabelMask) | (UInt16((clamped << 1)) & finderLabelMask)
    bytes[8] = UInt8((flags >> 8) & 0xff)
    bytes[9] = UInt8(flags & 0xff)
    data = Data(bytes)
    try Xattr.set(name: finderInfoAttr, value: data, atPath: path)
  }

  static func buildUserTagsPlistData(tags: [TagDefinition]) throws -> Data {
    let values = tags.map { tag in
      "\(tag.name.trimmingCharacters(in: .whitespacesAndNewlines))\n\(max(0, min(7, tag.colorIndex)))"
    }
    return try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0)
  }

  static func setOrderedUserTags(atPath path: String, tags: [TagDefinition]) async throws -> Bool {
    let normalized = tags
      .map { TagDefinition(name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines), colorIndex: $0.colorIndex) }
      .filter { !$0.name.isEmpty }

    guard !normalized.isEmpty else {
      throw NSError(domain: "tag", code: 1, userInfo: [NSLocalizedDescriptionKey: "No tags provided."])
    }

    let primaryColorIndex = normalized.first(where: { $0.colorIndex > 0 })?.colorIndex ?? 0
    let newData = try buildUserTagsPlistData(tags: normalized)

    if let existing = try Xattr.get(name: userTagsAttr, atPath: path) {
      if existing == newData {
        let existingLabel = try getFinderLabelIndex(atPath: path)
        if existingLabel == primaryColorIndex {
          return false
        }
      }
    }

    try Xattr.remove(name: userTagsAttr, atPath: path)
    try await Task.sleep(nanoseconds: 200_000_000)
    try Xattr.set(name: userTagsAttr, value: newData, atPath: path)
    try setFinderLabelIndex(atPath: path, colorIndex: primaryColorIndex)
    return true
  }
}

