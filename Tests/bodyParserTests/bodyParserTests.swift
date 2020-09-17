import XCTest
import Macro
@testable import http
@testable import connect

final class bodyParserTests: XCTestCase {
  
  func testStringParser() throws {
    let req = IncomingMessage(
      .init(version: .init(major: 1, minor: 1),
            method: .POST, uri: "/post", headers: [
              "Content-Type": "text/html"
            ])
    )

    req.push(Buffer("Hello World"))
    req.push(nil) // EOF

    let sem = expectation(description: "parsing body ...")

    // This is using pipes, and pipes need to (currently) happen on the
    // same eventloop.
    MacroCore.shared.fallbackEventLoop().execute {
      let res = ServerResponse(unsafeChannel: nil, log: req.log)
      
      // this is using concat ... so we need an expectations
      let mw = bodyParser.text()
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
      
      guard case .text(let value) = req.body else {
        XCTFail("returned value is not a text")
        return
      }
      
      XCTAssertEqual(value, "Hello World")
    }
  }
  
  func testArrayFormValueParser() throws {
    let req = IncomingMessage(
      .init(version: .init(major: 1, minor: 1),
            method: .POST, uri: "/post", headers: [
              "Content-Type": "application/x-www-form-urlencoded"
            ])
    )

    req.push(Buffer("a[]=1&a[]=2"))
    req.push(nil) // EOF

    let sem = expectation(description: "parsing body ...")

    // This is using pipes, and pipes need to (currently) happen on the
    // same eventloop.
    MacroCore.shared.fallbackEventLoop().execute {
      let res = ServerResponse(unsafeChannel: nil, log: req.log)
      
      // this is using concat ... so we need an expectations
      let mw = bodyParser.urlencoded()
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
  }

  static var allTests = [
    ( "testStringParser", testStringParser )
  ]
}
