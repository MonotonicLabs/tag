import Foundation

func pathIsAtOrUnderRoot(_ path: String, root: String) -> Bool {
  if root == "/" {
    return path.hasPrefix("/")
  }

  if path == root {
    return true
  }

  let prefix = root.hasSuffix("/") ? root : root + "/"
  return path.hasPrefix(prefix)
}

