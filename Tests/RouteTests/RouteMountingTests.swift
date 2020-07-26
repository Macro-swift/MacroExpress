import XCTest
import MacroTestUtilities
import class     http.IncomingMessage
@testable import express

final class RouteMountingTests: XCTestCase {
    
  func testSimpleMountMatch() throws {
    let outerRoute = Route()

    // match /admin/view
    var didCallRoute = false
    outerRoute.route("/admin")
      .get("/view") { req, res, next in
        XCTAssertEqual(req.baseURL, "/admin/view", "baseURL does not match")
        XCTAssertEqual(req.url,     "/admin/view", "HTTP URL does not match")
        didCallRoute = true
      }
    
    // test
    
    let req = IncomingMessage(
      .init(version: .init(major: 1, minor: 1), method: .GET,
            uri: "/admin/view"))
    let res = TestServerResponse()
    
    var didCallNext = false
    try outerRoute.handle(request: req, response: res) { ( args : Any... ) in
      XCTAssertTrue(args.isEmpty, "toplevel next called w/ arguments \(args)")
      didCallNext = true
    }
    XCTAssertTrue (didCallRoute, "not handled by middleware")
    XCTAssertFalse(didCallNext,  "not handled by middleware (did call next)")
  }
  
  func testSimpleErrorMountMatch() throws {
    enum SomeError: Swift.Error {
      case thisWentWrong
    }
    
    let outerRoute = Route()

    // match /admin/view
    var didCallErrorMiddleware    = false
    var didCallThrowingMiddleware = false
    outerRoute.route(id: "outer", "/admin")
      .get(id: "error", "/view") { error, req, res, next in
        XCTAssertEqual(req.baseURL, "/admin/view", "baseURL does not match")
        XCTAssertEqual(req.url,     "/admin/view", "HTTP URL does not match")
        didCallErrorMiddleware = true
      }
      .use(id: "thrower") { req, res, next in
        didCallThrowingMiddleware = true
        throw SomeError.thisWentWrong
      }
    
    // test
    
    let req = IncomingMessage(
      .init(version: .init(major: 1, minor: 1), method: .GET,
            uri: "/admin/view"))
    let res = TestServerResponse()
    
    var didCallNext = false
    try outerRoute.handle(request: req, response: res) { ( args : Any... ) in
      XCTAssertTrue(args.isEmpty, "toplevel next called w/ arguments \(args)")
      didCallNext = true
    }
    XCTAssertTrue (didCallThrowingMiddleware, "not handled by middleware")
    XCTAssertTrue (didCallErrorMiddleware, "not handled by error middleware")
    XCTAssertFalse(didCallNext,  "not handled by middleware (did call next)")
  }

  static var allTests = [
    ( "testSimpleMountMatch"      , testSimpleMountMatch      ),
    ( "testSimpleErrorMountMatch" , testSimpleErrorMountMatch )
  ]
}
