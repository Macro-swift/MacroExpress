import XCTest
import MacroCore
import http
import connect
@testable import multer

final class multerTests: XCTestCase {
  
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

  static var allTests = [
    ( "testSimpleAny"      , testSimpleAny      ),
    ( "testSimpleNoneFail" , testSimpleNoneFail ),
    ( "testSimpleSingleOK" , testSimpleSingleOK ),
    ( "testSingleFail"     , testSingleFail     ),
    ( "testMultiOK"        , testMultiOK        ),
    ( "testSizeLimit"      , testSizeLimit      )
  ]
}
