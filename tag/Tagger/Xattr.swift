import Darwin
import Foundation

enum XattrError: Error, CustomStringConvertible {
  case failed(function: String, path: String, name: String, errno: Int32)

  var description: String {
    switch self {
    case let .failed(function, path, name, errno):
      let message = String(cString: strerror(errno))
      return "\(function) failed for \(name) on \(path): \(message) (\(errno))"
    }
  }
}

enum Xattr {
  static func get(name: String, atPath path: String) throws -> Data? {
    errno = 0
    let size = getxattr(path, name, nil, 0, 0, 0)
    if size < 0 {
      if errno == ENOATTR { return nil }
      throw XattrError.failed(function: "getxattr", path: path, name: name, errno: errno)
    }

    var data = Data(count: size)
    let readSize = data.withUnsafeMutableBytes { buffer -> ssize_t in
      guard let baseAddress = buffer.baseAddress else { return -1 }
      errno = 0
      return getxattr(path, name, baseAddress, size, 0, 0)
    }
    if readSize < 0 {
      throw XattrError.failed(function: "getxattr", path: path, name: name, errno: errno)
    }
    return data
  }

  static func set(name: String, value: Data, atPath path: String) throws {
    let result = value.withUnsafeBytes { buffer -> Int32 in
      guard let baseAddress = buffer.baseAddress else { return -1 }
      errno = 0
      return setxattr(path, name, baseAddress, value.count, 0, 0)
    }
    if result != 0 {
      throw XattrError.failed(function: "setxattr", path: path, name: name, errno: errno)
    }
  }

  static func remove(name: String, atPath path: String) throws {
    errno = 0
    let result = removexattr(path, name, 0)
    if result != 0 {
      if errno == ENOATTR { return }
      throw XattrError.failed(function: "removexattr", path: path, name: name, errno: errno)
    }
  }
}

