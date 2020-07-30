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
      }
      console.log("REQ:", req.body)
    }
  }

  static var allTests = [
    ( "testStringParser", testStringParser )
  ]
}
