//
//  DiskStorage.swift
//  MacroExpress / multer
//
//  Created by Helge Heß on 30/05/16.
//  Copyright © 2021-2026 ZeeZide GmbH. All rights reserved.
//

import struct   Foundation.UUID
import struct   MacroCore.Buffer
import class    http.IncomingMessage
import fs
import NIOConcurrencyHelpers

public extension multer {

  enum DiskStorageError: Swift.Error, Sendable {
    case cannotCreateDirectory  (path: String, underlying: Swift.Error)
    case cannotCreateFile       (path: String)
    case writeFailed            (path: String, underlying: Swift.Error)
    case destinationLookupFailed(Swift.Error)
    case filenameLookupFailed   (Swift.Error)
  }
}

extension multer {

  /**
   * A ``MulterStorage`` that streams file contents to disk as the multipart
   * body is parsed.
   *
   * ```swift
   * let upload = multer(storage: multer.DiskStorage("/tmp/up"))
   * router.post("/u", upload.single("file")) { req, res, _ in
   *   // req.file?.path now points at the written file
   * }
   * ```
   *
   * `destination` and `filename` are called from the storage's `startFile`
   * hook which is synchronous, selector closures MUST yield their result
   * inline.
   */
  open class DiskStorage: MulterStorage {
    
    public typealias DestinationSelector = (
      IncomingMessage, File,
      @escaping ( Swift.Error?, String ) -> Void
    ) -> Void

    public typealias FilenameSelector = (
      IncomingMessage, File,
      @escaping ( Swift.Error?, String ) -> Void
    ) -> Void

    public let destination : DestinationSelector
    public let filename    : FilenameSelector?

    /// Per-file open streams and byte counts. Keyed by
    /// `ObjectIdentifier(file)` so concurrent uploads
    /// across requests don't collide.
    private struct FileState {
      var stream  : FileWriteStream
      var written : Int
    }
    private let state = NIOLockedValueBox([ ObjectIdentifier : FileState ]())

    public init(destination : @escaping DestinationSelector,
                filename    : FilenameSelector? = nil)
    {
      self.destination = destination
      self.filename    = filename
    }

    public convenience init(_ destination: String) {
      self.init(destination: { _, _, yield in yield(nil, destination) })
    }


    // MARK: - Storage API

    public func startFile(_ file: multer.File, in ctx: MulterStorageContext,
                          completion: @escaping ( Swift.Error? ) -> Void)
    {
      var destPath: String?
      var destErr : Swift.Error?
      destination(ctx.request, file) { e, p in
        destErr = e; destPath = p
      }
      if let e = destErr {
        return completion(DiskStorageError.destinationLookupFailed(e))
      }
      guard let dir = destPath else {
        return completion(DiskStorageError.cannotCreateFile(
          path: "(no destination yielded)"))
      }

      // Resolve filename, if a selector was given.
      // Default: random UUID + original extension.
      let name: String
      if let sel = filename {
        var n: String?
        var e: Swift.Error?
        sel(ctx.request, file) { err, v in e = err; n = v }
        if let err = e {
          return completion(DiskStorageError.filenameLookupFailed(err))
        }
        name = n ?? Self.defaultFilename(for: file)
      }
      else { name = Self.defaultFilename(for: file) }

      // One-shot mkdir per upload. Sync, but cheap and rare.
      do { try fs.mkdirSync(dir, .init(recursive: true)) }
      catch {
        return completion(DiskStorageError.cannotCreateDirectory(
          path: dir, underlying: error))
      }

      let fullPath = path.join(dir, name)
      let stream = fs.createWriteStream(
        on: ctx.request.socket?.eventLoop, fullPath)

      stream.onError { error in
        ctx.handleError(DiskStorageError.writeFailed(
          path: fullPath, underlying: error))
      }

      file.path = fullPath
      state.withLockedValue {
        $0[ObjectIdentifier(file)] = FileState(stream: stream, written: 0)
      }
      // The stream opens asynchronously on `fs.threadPool`; writes issued
      // before open completes are buffered by `FileWriteStream`. So we can
      // signal completion right away and let any open error surface via
      // `onError`.
      completion(nil)
    }

    public func write(_ data: Buffer, to file: multer.File,
                      in ctx: MulterStorageContext)
    {
      let id = ObjectIdentifier(file)
      enum WriteOutcome { case missing, write(FileWriteStream), overLimit }
      let outcome = state.withLockedValue { dict -> WriteOutcome in
        guard var s = dict[id] else { return .missing }
        s.written += data.count
        dict[id] = s
        if let limit = ctx.config.limits.fileSize, s.written > limit {
          return .overLimit
        }
        return .write(s.stream)
      }
      switch outcome {
        case .missing   : return
        case .overLimit : return ctx.handleError(MulterError.fileTooLarge)
        case .write(let stream):
          _ = stream.write(data, whenDone: {})
      }
    }

    public func endFile(_ file: multer.File, in ctx: MulterStorageContext,
                        completion: @escaping ( Swift.Error? ) -> Void)
    {
      let stream = state.withLockedValue {
        $0.removeValue(forKey: ObjectIdentifier(file))?.stream
      }
      guard let stream else { return completion(nil) }

      _ = stream.onFinish { completion(nil) }
      stream.end()
    }

    // MARK: - Helpers

    /// Default filename when the caller didn't pass a `filename` selector.
    /// UUID + the part's extension (if any).
    private static func defaultFilename(for file: multer.File) -> String {
      let uuid = UUID().uuidString
        .replacingOccurrences(of: "-", with: "")
        .lowercased()
      return uuid + path.extname(file.originalName)
    }
  }
}
