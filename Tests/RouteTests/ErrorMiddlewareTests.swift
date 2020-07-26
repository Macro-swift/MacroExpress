import XCTest
import MacroTestUtilities
import class     http.IncomingMessage
@testable import express

final class ErrorMiddlewareTests: XCTestCase {
  
  func testSimpleThrowErrorHandler() throws {
    enum SomeError: Swift.Error {
      case thisWentWrong
    }
    
    let route = Route(id: "root")
    
    // install error handler
    
    var errorCatched : Swift.Error? = nil
    route.use(id: "handler") { error, req, res, next in
      XCTAssertNil(errorCatched)
      errorCatched = error
    }
    
    // install throwing route
    
    route.use(id: "thrower") { req, res, next in
      throw SomeError.thisWentWrong
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
    XCTAssertFalse (didCallNext,  "error not handled by error middleware")
    XCTAssertNotNil(errorCatched, "no error captured by error middleware")
    XCTAssert      (errorCatched is SomeError, "different error type captured")
    if let error = errorCatched as? SomeError {
      XCTAssertEqual(error, SomeError.thisWentWrong,
                     "different error captured")
    }
  }
  
  func testSimpleNextErrorHandler() throws {
    enum SomeError: Swift.Error {
      case thisWentWrong
    }
    
    let route = Route(id: "root")
    
    // install error handler
    
    var errorCatched : Swift.Error? = nil
    route.use { error, req, res, next in
      XCTAssertNil(errorCatched)
      errorCatched = error
    }
    
    // install throwing route
    
    route.use { req, res, next in
      next(SomeError.thisWentWrong)
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
    XCTAssertFalse (didCallNext,  "error not handled by error middleware")
    XCTAssertNotNil(errorCatched, "no error captured by error middleware")
    XCTAssert      (errorCatched is SomeError, "different error type captured")
    if let error = errorCatched as? SomeError {
      XCTAssertEqual(error, SomeError.thisWentWrong,
                     "different error captured")
    }
  }

  static var allTests = [
    ( "testSimpleThrowErrorHandler" , testSimpleThrowErrorHandler ),
    ( "testSimpleNextErrorHandler"  , testSimpleNextErrorHandler  ),
  ]
}
