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
  
  func testSimpleMultiPartFormDataParser() throws {
    let boundary = "----WebKitFormBoundaryHU6Dqpfe9L4ATppg"
    
    let req = IncomingMessage(
      .init(version: .init(major: 1, minor: 1),
            method: .POST, uri: "/post", headers: [
              "Content-Type": "multipart/form-data; boundary=\(boundary)"
            ])
    )
    
    let requestBody = Buffer(
      """
      --\(boundary)\r
      Content-Disposition: form-data; name="title"\r
      \r
      file.csv\r
      --\(boundary)\r
      Content-Disposition: form-data; name="file"; filename=""\r
      Content-Type: application/octet-stream\r
      \r
      \r
      --\(boundary)--\r\n
      """
    )
    
    let loop = MacroCore.shared.fallbackEventLoop()
    let sem  = expectation(description: "parsing body ...")
    
    req.push(requestBody)
    req.push(nil) // EOF

    // TBD: What is the pipe situation here? Do we really use them?
    loop.execute {
      let res = ServerResponse(unsafeChannel: nil, log: req.log)
      
      let mw = multer().none()
      do {
        try mw(req, res) { ( args : Any...) in
          console.log("done parsing ...", args)
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
        XCTFail("expection returned in error")
      }
      
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
      #if false
      do {
        guard case .urlEncoded(let dict) = req.body else {
          XCTFail("returned value is not url encoded")
          return
        }
        
        guard let typedDict = dict as? [ String : [ String ] ] else {
          XCTFail("returned value is not the expected dict type")
          return
        }
        XCTAssertEqual(typedDict, [ "a": [ "1", "2" ]])
      }
      #endif
    }
  }
 
  static var allTests = [
    ( "testSimpleMultiPartFormDataParser" , testSimpleMultiPartFormDataParser )
  ]
}
