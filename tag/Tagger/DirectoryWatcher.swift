import Darwin
import Foundation

final class DirectoryWatcher {
  private let directoryURL: URL
  private let handler: @Sendable () -> Void
  private let queue: DispatchQueue

  private var source: DispatchSourceFileSystemObject?
  private var fileDescriptor: Int32 = -1

  init(directoryURL: URL, queue: DispatchQueue? = nil, handler: @escaping @Sendable () -> Void) {
    self.directoryURL = directoryURL
    self.queue = queue ?? DispatchQueue(label: "tag.directory-watcher.\(UUID().uuidString)")
    self.handler = handler
  }

  deinit {
    stop()
  }

  func start() throws {
    if source != nil { return }

    fileDescriptor = open(directoryURL.path, O_EVTONLY)
    guard fileDescriptor >= 0 else {
      throw POSIXError(.EBADF)
    }

    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fileDescriptor,
      eventMask: [.write, .delete, .rename],
      queue: queue
    )

    source.setEventHandler { [handler] in
      handler()
    }

    source.setCancelHandler { [fileDescriptor] in
      close(fileDescriptor)
    }

    self.source = source
    source.resume()
  }

  func stop() {
    guard let source else { return }
    self.source = nil
    source.cancel()
  }
}

