import XCTest
import let    MacroCore.console
import struct MacroCore.Buffer
import class  MacroCore.MacroCore
@testable import http
@testable import connect

final class multerTests: XCTestCase {
  
  func TODOtestSimpleMultiPartFormDataParser() throws {
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
      --\(boundary)--\r
      """
    )

    req.push(requestBody)
    req.push(nil) // EOF

    let sem = expectation(description: "parsing body ...")
    
    // This is using pipes, and pipes need to (currently) happen on the
    // same eventloop.
    MacroCore.shared.fallbackEventLoop().execute {
      let res = ServerResponse(unsafeChannel: nil, log: req.log)
      
      // this is using concat ... so we need an expectations
      #if false
        let mw = multer.none()
      #else
        let mw = bodyParser.urlencoded()
      #endif
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
  
  func testDummy() {}
 
  static var allTests = [
    ( "testSimpleMultiPartFormDataParser" , testDummy )
      // testSimpleMultiPartFormDataParser )
  ]
}
