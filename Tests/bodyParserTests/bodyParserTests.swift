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
    req.push(nil)
    // how to end/finish?

    let res = ServerResponse(unsafeChannel: nil, log: req.log)
    
    // this is using concat ... so we need an expectations
    let sem = expectation(description: "parsing body ...")
    let mw = bodyParser.text()
    try mw(req, res) { ( args : Any...) in
      console.log("done parsing ...", args)
      sem.fulfill()
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
