import XCTest
import MacroTestUtilities
import class     http.IncomingMessage
@testable import express

final class SimpleRouteTests: XCTestCase {
  
  func testSimpleEndingRoute() throws {
    let route = Route(id: "root")
    
    var didCallRoute = false
    route.use { req, res, next in
      didCallRoute = true
    }
    
    // test
    
    let req = IncomingMessage(
      .init(version: .init(major: 1, minor: 1), method: .POST, uri: "/hello"))
    let res = TestServerResponse()
    
    var didCallNext = false
    try route.handle(request: req, response: res) { ( args : Any... ) in
      XCTAssertTrue(args.isEmpty, "toplevel next called w/ arguments \(args)")
      didCallNext = true
    }
    XCTAssertTrue (didCallRoute, "not handled by middleware")
    XCTAssertFalse(didCallNext,  "not handled by middleware (did call next)")
  }
  
  func testSimpleNonEndingRoute() throws {
    let route = Route()
    
    var didCallRoute = false
    route.use { req, res, next in
      didCallRoute = true
      next()
    }
    
    // test
    
    let req = IncomingMessage(
      .init(version: .init(major: 1, minor: 1), method: .POST, uri: "/hello"))
    let res = TestServerResponse()
    
    var didCallNext = false
    try route.handle(request: req, response: res) { ( args : Any... ) in
      XCTAssertTrue(args.isEmpty, "toplevel next called w/ arguments \(args)")
      didCallNext = true
    }
    XCTAssertTrue(didCallRoute, "middleware not called")
    XCTAssertTrue(didCallNext,  "next not called as expected")
  }

  static var allTests = [
    ( "testSimpleEndingRoute"    , testSimpleEndingRoute    ),
    ( "testSimpleNonEndingRoute" , testSimpleNonEndingRoute )
  ]
}
