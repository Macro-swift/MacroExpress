import XCTest
import Foundation
import MacroCore
import struct NIO.ByteBuffer
import NIOConcurrencyHelpers
import http
import connect
import fs
@testable import multer

final class multerTests: XCTestCase, @unchecked Sendable {
  
  override class func setUp() {
    super.setUp()
    disableAtExitHandler()
  }
  
  func testSimpleAny() throws {
    typealias fixture = Fixtures.SimpleFormData
    
    let loop = MacroCore.shared.fallbackEventLoop()
    let sem  = expectation(description: "parsing body ...")
    let req  = fixture.request

    // TBD: What is the pipe situation here? Do we really use them?
    loop.execute {
      let res = ServerResponse(unsafeChannel: nil, log: req.log)
      
      let mw = multer().any()
      do {
        try mw(req, res) { ( args : Any...) in
          XCTAssertEqual(args.count, 0)
          sem.fulfill()
        }
      }
      catch {
        sem.fulfill()
      }
    }

    waitForExpectations(timeout: 3) { error in
      if let error = error {
        console.log("Error:", error.localizedDescription)
        XCTFail("expection returned an error")
      }
      
      XCTAssertEqual(req.body.count  , 1)
      XCTAssertEqual(req.files.count , 1)
      
      do {
        guard let value = req.body.title else {
          XCTFail("body has no 'title' value")
          return
        }
        guard let title = value as? String else {
          XCTFail("'title' body does not have the expected String value")
          return
        }
        XCTAssertEqual(title, "file.csv")
      }
      
      do {
        guard case .urlEncoded(let dict) = req.body else {
          XCTFail("returned value is not url encoded")
          return
        }
        
        guard let typedDict = dict as? [ String : String ] else {
          XCTFail("returned value is not the expected dict type")
          return
        }
        XCTAssertEqual(typedDict, [ "title": "file.csv" ])
      }
      
      if let file = req.files.first?.value.first {
        XCTAssertEqual(file.fieldName , "file")
        XCTAssertNil  (file.filename)
        XCTAssertEqual(file.buffer?.count ?? 0, 0) // empty!
      }
    }
  }
  
  func testSimpleNoneFail() throws {
    typealias fixture = Fixtures.SimpleFormData
    
    let loop = MacroCore.shared.fallbackEventLoop()
    let sem  = expectation(description: "parsing body ...")
    let req  = fixture.request

    loop.execute {
      let res = ServerResponse(unsafeChannel: nil, log: req.log)
      
      let mw = multer().none()
      do {
        try mw(req, res) { ( args : Any...) in
          if let error = args.first as? multer.MulterError {
            switch error {
              case .limitUnexpectedFile(let fieldName):
                XCTAssertEqual(fieldName, "file")
              default:
                XCTAssert(false, "Got a different multer error: \(error)")
            }
          }
          else {
            XCTAssert(false, "Expected a multer error, got: \(args)")
          }
          sem.fulfill()
        }
      }
      catch {
        sem.fulfill()
      }
    }
    
    waitForExpectations(timeout: 3)
  }
  
  func testSimpleSingleOK() throws {
    typealias fixture = Fixtures.SimpleFormData
    
    let loop = MacroCore.shared.fallbackEventLoop()
    let sem  = expectation(description: "parsing body ...")
    let req  = fixture.request

    loop.execute {
      let res = ServerResponse(unsafeChannel: nil, log: req.log)
      
      let mw = multer().single("file")
      do {
        try mw(req, res) { ( args : Any...) in
          XCTAssertEqual(args.count, 0)
          sem.fulfill()
        }
      }
      catch {
        sem.fulfill()
      }
    }
    
    waitForExpectations(timeout: 3) { error in
      if let error = error { XCTFail("expection returned \(error)") }

      XCTAssertEqual(req.files.count , 1)
      if let file = req.files.first?.value.first {
        XCTAssertEqual(file.fieldName , "file")
        XCTAssertNil  (file.filename)
        XCTAssertEqual(file.buffer?.count ?? 0, 0) // empty!
      }
    }
  }
  
  func testSingleFail() throws {
    typealias fixture = Fixtures.TwoFilesSubmit
    
    let loop = MacroCore.shared.fallbackEventLoop()
    let sem  = expectation(description: "parsing body ...")
    let req  = fixture.request

    loop.execute {
      let res = ServerResponse(unsafeChannel: nil, log: req.log)
      
      let mw = multer().single("file")
      do {
        try mw(req, res) { ( args : Any...) in
          if let error = args.first as? multer.MulterError {
            switch error {
              case .tooManyFiles:
                break
              default:
                XCTAssert(false, "Got a different multer error: \(error)")
            }
          }
          else {
            XCTAssert(false, "Expected a multer error, got: \(args)")
          }
          sem.fulfill()
        }
      }
      catch {
        sem.fulfill()
      }
    }
    
    waitForExpectations(timeout: 3)
  }

  func testFieldNameMismatchYieldsLimitUnexpectedFile() throws {
    typealias fixture = Fixtures.SimpleFormData

    let loop = MacroCore.shared.fallbackEventLoop()
    let sem  = expectation(description: "parsing body ...")
    let req  = fixture.request

    loop.execute {
      let res = ServerResponse(unsafeChannel: nil, log: req.log)

      // Fixture's file part is named "file", use a name that doesn't match.
      let mw = multer().array("uploads", 10)
      do {
        try mw(req, res) { ( args : Any...) in
          defer { sem.fulfill() }

          XCTAssert(args.first is multer.MulterError,
                    "expected a multer error, got: \(args)")
          guard let error = args.first as? multer.MulterError else { return }
          switch error {
            case .limitUnexpectedFile(let fieldName):
              XCTAssertEqual(fieldName, "file",
                             "error should carry the offending field name")
            default:
              XCTFail("expected limitUnexpectedFile, got: \(error)")
          }
        }
      }
      catch {
        sem.fulfill()
      }
    }

    waitForExpectations(timeout: 3)
  }

  func testEmpty() throws {
    typealias fixture = Fixtures.EmptyFile
    
    let loop = MacroCore.shared.fallbackEventLoop()
    let sem  = expectation(description: "parsing body ...")
    let req  = fixture.request

    loop.execute {
      let res = ServerResponse(unsafeChannel: nil, log: req.log)
      
      let mw = multer().array("file", 2)
      do {
        try mw(req, res) { ( args : Any...) in
          XCTAssertEqual(args.count, 0)
          sem.fulfill()
        }
      }
      catch {
        sem.fulfill()
      }
    }
    
    waitForExpectations(timeout: 3) { error in
      if let error = error { XCTFail("expection returned \(error)") }

      XCTAssertEqual(req.files.count, 1) // this still has an entry!
      XCTAssertEqual(req.files["file"]?.count ?? 0, 0) // but no files
      XCTAssertNil(req.files["file"]?.first)
    }
  }
  
  func testMultiOK() throws {
    typealias fixture = Fixtures.TwoFilesSubmit
    
    let loop = MacroCore.shared.fallbackEventLoop()
    let sem  = expectation(description: "parsing body ...")
    let req  = fixture.request

    loop.execute {
      let res = ServerResponse(unsafeChannel: nil, log: req.log)
      
      let mw = multer().array("file", 2)
      do {
        try mw(req, res) { ( args : Any...) in
          XCTAssertEqual(args.count, 0)
          sem.fulfill()
        }
      }
      catch {
        sem.fulfill()
      }
    }
    
    waitForExpectations(timeout: 3) { error in
      if let error = error { XCTFail("expection returned \(error)") }

      XCTAssertEqual(req.files.count, 1)
      XCTAssertEqual(req.files["file"]?.count ?? 0, 2)

      if let file = req.files.first?.value.first {
        XCTAssertEqual(file.fieldName    , "file")
        XCTAssertEqual(file.originalName , fixture.filenames.first)
        XCTAssertEqual(file.buffer?.count ?? 0, fixture.cFile.count)
      }
      
      if let file = req.files.first?.value.dropFirst().first {
        XCTAssertEqual(file.fieldName    , "file")
        XCTAssertEqual(file.originalName , fixture.filenames.dropFirst().first)
        XCTAssertEqual(file.buffer?.count ?? 0, fixture.icon.count)
      }
    }
  }
  
  func testSizeLimit() throws {
    typealias fixture = Fixtures.ImageSubmitData
    
    let loop = MacroCore.shared.fallbackEventLoop()
    let sem  = expectation(description: "parsing body ...")
    let req  = fixture.request

    loop.execute {
      let res = ServerResponse(unsafeChannel: nil, log: req.log)
      
      var limits = multer.Limits()
      limits.fileSize = 1024 // 1KB
      
      let mw = multer(limits: limits).single("file")
      do {
        try mw(req, res) { ( args : Any...) in
          if let error = args.first as? multer.MulterError {
            switch error {
              case .fileTooLarge:
                break
              default:
                XCTAssert(false, "Got a different multer error: \(error)")
            }
          }
          else {
            XCTAssert(false, "Expected a multer error, got: \(args)")
          }
          sem.fulfill()
        }
      }
      catch {
        sem.fulfill()
      }
    }
    
    waitForExpectations(timeout: 3)
  }
  
  // MARK: - Disk Storage

  /// Drives a multer instance configured with
  /// DiskStorage against the ImageSubmitData
  /// fixture (one PNG attachment), then asserts
  /// the file landed on disk with the expected
  /// bytes and that the in-memory buffer is nil
  /// (i.e. the storage really streamed past RAM).
  func testDiskStorageWritesToTempDir() throws {
    typealias fixture = Fixtures.ImageSubmitData

    let dest = NSTemporaryDirectory() + "multer-disk-test-\(UUID().uuidString)"
    addTeardownBlock {
      try? fs.rmdirSync(dest)
    }
    let storage = multer.diskStorage(dest)
    let m = multer(storage: storage)

    let loop = MacroCore.shared.fallbackEventLoop()
    let sem  = expectation(description: "disk")
    let req  = fixture.request

    loop.execute {
      let res = ServerResponse(
        unsafeChannel: nil, log: req.log
      )
      let mw = m.single("file")
      do {
        try mw(req, res) { _ in sem.fulfill() }
      }
      catch { sem.fulfill() }
    }
    waitForExpectations(timeout: 3)

    let files = req.files["file"] ?? []
    XCTAssertEqual(files.count, 1)
    guard let file = files.first else { return XCTFail("no file") }
    XCTAssertNotNil(file.path, "DiskStorage must set file.path")
    XCTAssertNil(file.buffer, "DiskStorage must not buffer in memory")

    guard let path = file.path else { return XCTFail("path missing") }
    XCTAssertTrue(FileSystemModule.existsSync(path))
    let onDisk = try XCTUnwrap(fs.readFileSync(path))
    XCTAssertEqual(onDisk.count, fixture.icon.count)
    XCTAssertEqual(onDisk, fixture.icon)
  }

  /// Custom filename selector + nested
  /// destination dir creation.
  func testDiskStorageHonoursFilenameSelector()
    throws
  {
    typealias fixture = Fixtures.ImageSubmitData

    let parent = NSTemporaryDirectory() + "multer-disk-sel-\(UUID().uuidString)"
    let dest = parent + "/sub/dir"
    addTeardownBlock {
      try? fs.rmdirSync(parent)
    }
    let storage = multer.diskStorage(
      destination: { _, _, yield in
        yield(nil, dest)
      },
      filename: { _, _, yield in
        yield(nil, "fixed-name.png")
      }
    )
    let m = multer(storage: storage)

    let loop = MacroCore.shared.fallbackEventLoop()
    let sem  = expectation(description: "disk-sel")
    let req  = fixture.request

    loop.execute {
      let res = ServerResponse(
        unsafeChannel: nil, log: req.log
      )
      let mw = m.single("file")
      do {
        try mw(req, res) { _ in sem.fulfill() }
      }
      catch { sem.fulfill() }
    }
    waitForExpectations(timeout: 3)

    let file = req.files["file"]?.first
    XCTAssertEqual(file?.path, "\(dest)/fixed-name.png")
    XCTAssertTrue(FileSystemModule.existsSync("\(dest)/fixed-name.png"))
  }

  /// Build a multipart/form-data body for one file
  /// part with the given content. Returns the
  /// boundary string + payload so a test can wire
  /// up an IncomingMessage.
  private func buildMultipart(
    fieldName: String, filename: String,
    contentType: String, body: Buffer
  )
    -> (boundary: String, payload: Buffer)
  {
    let boundary = "----macroexpressTestBoundary" + UUID().uuidString
      .replacingOccurrences(of: "-", with: "")
    var out = Buffer()
    out.append("--\(boundary)\r\n" + "Content-Disposition: form-data; "
               + "name=\"\(fieldName)\"; " + "filename=\"\(filename)\"\r\n"
               + "Content-Type: \(contentType)\r\n\r\n")
    out.append(body)
    out.append("\r\n--\(boundary)--\r\n")
    return (boundary, out)
  }

  /// Push raw multipart bytes through an
  /// IncomingMessage, mirroring how production
  /// requests deliver bodies in chunks.
  private func multipartRequest(
    boundary: String, payload: Buffer
  )
    -> IncomingMessage
  {
    let req = IncomingMessage(.init(
      version: .init(major: 1, minor: 1),
      method: .POST, uri: "/u",
      headers: ["Content-Type": "multipart/form-data; " +
        "boundary=\(boundary)"]
    ))
    req.push(payload)
    req.push(nil)
    return req
  }

  /// Stream a 4 MB synthetic file through
  /// DiskStorage and verify it lands on disk with
  /// the right bytes -- and that `file.buffer`
  /// stays nil (proving the bytes never went
  /// through the multer.File memory buffer).
  func testDiskStorageStreamsLargeFile() throws {
    let size = 4 * 1024 * 1024
    var raw = [ UInt8 ]( repeating: 0, count: size )
    for i in 0..<size {
      raw[i] = UInt8((i &* 31) & 0xFF)
    }
    let bytes = Buffer(raw)
    let (boundary, payload) = buildMultipart(
      fieldName: "file", filename: "big.bin",
      contentType: "application/octet-stream",
      body: bytes
    )

    let dest = NSTemporaryDirectory() + "multer-large-\(UUID().uuidString)"
    addTeardownBlock {
      try? fs.rmdirSync(dest)
    }
    let m = multer(storage: multer.diskStorage(dest))

    let loop = MacroCore.shared.fallbackEventLoop()
    let sem  = expectation(description: "stream")
    let req  = multipartRequest(
      boundary: boundary, payload: payload
    )
    loop.execute {
      let res = ServerResponse(
        unsafeChannel: nil, log: req.log
      )
      let mw = m.single("file")
      do {
        try mw(req, res) { _ in sem.fulfill() }
      }
      catch { sem.fulfill() }
    }
    waitForExpectations(timeout: 10)

    let file = req.files["file"]?.first
    XCTAssertNotNil(file)
    XCTAssertNotNil(file?.path)
    XCTAssertNil(file?.buffer, "DiskStorage must NOT buffer large files")
    guard let p = file?.path else { return }
    let onDisk = try XCTUnwrap(fs.readFileSync(p))
    XCTAssertEqual(onDisk.count, size)
    XCTAssertEqual(onDisk, bytes)
  }

  /// A file larger than `multer.Limits.fileSize`
  /// must surface a `fileTooLarge` error and not
  /// leak unbounded bytes to disk.
  func testDiskStorageEnforcesFileSizeLimit()
    throws
  {
    let size = 200_000
    let bytes = Buffer(
      [ UInt8 ]( repeating: 0x42, count: size )
    )
    let (boundary, payload) = buildMultipart(
      fieldName: "file", filename: "over.bin",
      contentType: "application/octet-stream",
      body: bytes
    )

    let dest = NSTemporaryDirectory() + "multer-limit-\(UUID().uuidString)"
    addTeardownBlock {
      try? fs.rmdirSync(dest)
    }
    var limits = multer.Limits()
    limits.fileSize = 100_000 // half the body
    let m = multer(
      storage: multer.diskStorage(dest),
      limits: limits
    )

    let loop = MacroCore.shared.fallbackEventLoop()
    let sem  = expectation(description: "limit")
    let errBox = NIOLockedValueBox<Any?>(nil)
    let req  = multipartRequest(
      boundary: boundary, payload: payload
    )
    loop.execute {
      let res = ServerResponse(
        unsafeChannel: nil, log: req.log
      )
      let mw = m.single("file")
      do {
        try mw(req, res) { args in
          errBox.withLockedValue { $0 = args }
          sem.fulfill()
        }
      }
      catch {
        errBox.withLockedValue { $0 = error }
        sem.fulfill()
      }
    }
    waitForExpectations(timeout: 5)

    // Either `next(error)` carried fileTooLarge,
    // OR `req.body` was set to .error(...). Both
    // are valid surfacings of the limit.
    let nextArgs = errBox.withLockedValue { $0 }
    var sawLimit = false
    if let arr = nextArgs as? [ Any ],
       let err = arr.first as? multer.MulterError,
       case .fileTooLarge = err { sawLimit = true }
    if case .error(let e) = req.body,
       let merr = e as? multer.MulterError,
       case .fileTooLarge = merr { sawLimit = true }
    XCTAssertTrue(sawLimit, "expected MulterError.fileTooLarge"
                  + ", got next=\(String(describing: nextArgs))" +
                  " body=\(req.body)")
  }

  /// Two files in one upload, distinct
  /// `att_<n>_*` filenames via a custom filename
  /// selector -- mirrors the SwiftSOGo mail draft
  /// route's selector shape.
  func testDiskStorageMultipleFilesGetDistinctNames()
    throws
  {
    typealias fixture = Fixtures.TwoFilesSubmit
    let dest = NSTemporaryDirectory() + "multer-multi-\(UUID().uuidString)"
    addTeardownBlock {
      try? fs.rmdirSync(dest)
    }
    // The selector is invoked once per file, sequentially on the multer
    // processing context's thread, so a captured counter is enough.
    let nextIdx = NIOLockedValueBox(0)
    let storage = multer.diskStorage(
      destination: { _, _, yield in yield(nil, dest) },
      filename:    { _, file, yield in
        let idx = nextIdx.withLockedValue { v -> Int in
          defer { v += 1 }; return v
        }
        yield(nil, "att_\(idx)_" + file.originalName)
      }
    )
    let m = multer(storage: storage)

    let loop = MacroCore.shared.fallbackEventLoop()
    let sem  = expectation(description: "multi")
    let req  = fixture.request
    loop.execute {
      let res = ServerResponse(
        unsafeChannel: nil, log: req.log
      )
      let mw = m.fields([
                        ( fieldName: "file", maxCount: nil )
                        ])
      do {
        try mw(req, res) { _ in sem.fulfill() }
      }
      catch { sem.fulfill() }
    }
    waitForExpectations(timeout: 5)

    let files = req.files["file"] ?? []
    XCTAssertEqual(files.count, 2)
    let names = files.compactMap { $0.path.map(path.basename) }.sorted()
    XCTAssertEqual(names, [ "att_0_hello.c", "att_1_bugicon.png" ])
    // Bytes match for both.
    let cContent = try XCTUnwrap(
      fs.readFileSync(path.join(dest, "att_0_hello.c"))
    )
    XCTAssertEqual(cContent, Buffer(fixture.cFile))
    let pngContent = try XCTUnwrap(
      fs.readFileSync(path.join(dest, "att_1_bugicon.png"))
    )
    XCTAssertEqual(pngContent, fixture.icon)
  }

  func testBufferRemainingMatchPerformance() {
    // Just make sure we don't hit cross-module surprises.
    let bb = Buffer(ByteBuffer(repeating: 0, count: 64 * 1024))
    let needle : [ UInt8 ] = [ 30, 50, 60, 30, 40, 25, 21, 22, 23, 24, 88, 18 ]
    
    let start = Date()
    measure {
      for _ in 0..<100 {
        let idxMaybe = bb
                         .indexOf(needle, options: .partialSuffixMatch)
        XCTAssertNotNil(idxMaybe)
      }
    }
    let duration = -start.timeIntervalSinceNow
    print("TOOK:", duration)
  }

  static let allTests = [
    ( "testSimpleAny"      , testSimpleAny      ),
    ( "testSimpleNoneFail" , testSimpleNoneFail ),
    ( "testSimpleSingleOK" , testSimpleSingleOK ),
    ( "testSingleFail"     , testSingleFail     ),
    ("testFieldNameMismatchYieldsLimitUnexpectedFile",
     testFieldNameMismatchYieldsLimitUnexpectedFile ),
    ( "testMultiOK"        , testMultiOK        ),
    ( "testSizeLimit"      , testSizeLimit      ),
    ("testBufferRemainingMatchPerformance",
     testBufferRemainingMatchPerformance )
  ]
}
