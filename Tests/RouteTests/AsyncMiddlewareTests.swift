//
//  AsyncMiddlewareTests.swift
//  MacroExpress
//
//  Created by Helge Hess.
//  Copyright © 2026 ZeeZide GmbH. All rights reserved.
//

import XCTest
import MacroTestUtilities
import class     http.IncomingMessage
import func      MacroCore.disableAtExitHandler
@testable import connect
@testable import express

final class AsyncMiddlewareTests: XCTestCase {

  override class func setUp() {
    super.setUp()
    disableAtExitHandler()
  }

  // MARK: - AsyncMiddleware (3-arg)

  func testAsyncMiddlewareCallsNext() throws {
    let route = Route(id: "root")
    let e     = expectation(description: "next called")

    route.use(async { req, res, next in next() })

    let req = IncomingMessage(url: "/hello")
    let res = TestServerResponse()

    try route.handle(request: req, response: res) { (args: Any...) in
      // This is the final next
      XCTAssertTrue(args.isEmpty)
      e.fulfill()
    }
    waitForExpectations(timeout: 3) { error in
      XCTAssertNil(error, "timed out waiting for next()")
    }
  }

  func testAsyncMiddlewareDoesNotCallNext() throws {
    let route = Route(id: "root")
    let e     = expectation(description: "middleware ran")

    var didCallMiddleware = false
    route.use(async { req, res, next in
      didCallMiddleware = true
      e.fulfill()
    })

    let req = IncomingMessage(url: "/hello")
    let res = TestServerResponse()

    var didCallNext = false
    try route.handle(request: req, response: res) { (args: Any...) in
      didCallNext = true
    }
    waitForExpectations(timeout: 3) { error in
      XCTAssertNil(error)
      XCTAssertTrue(didCallMiddleware)
      XCTAssertFalse(didCallNext)
    }
  }

  func testAsyncMiddlewareForwardsThrowToNext() throws {
    enum TestError: Swift.Error, Equatable { case bang }

    let route = Route(id: "root")
    let e     = expectation(description: "error forwarded")

    var errorCatched: Swift.Error?
    route.use { error, req, res, next in
      errorCatched = error
      e.fulfill()
    }
    route.use(async { req, res, next in throw TestError.bang })

    let req = IncomingMessage(url: "/hello")
    let res = TestServerResponse()

    try route.handle(request: req, response: res) { (args: Any...) in }

    waitForExpectations(timeout: 3) { error in
      XCTAssertNil(error, "timed out")
      XCTAssertNotNil(errorCatched)
      XCTAssert(errorCatched is TestError)
      if let err = errorCatched as? TestError {
        XCTAssertEqual(err, .bang)
      }
    }
  }

  func testAsyncMiddlewareCanAwait() throws {
    let route = Route(id: "root")
    let e     = expectation(description: "next called after await")

    var didAwait = false
    route.use(async { req, res, next in
      try await Task.sleep(nanoseconds: 1_000_000)
      didAwait = true
      next()
    })

    let req = IncomingMessage(url: "/hello")
    let res = TestServerResponse()

    try route.handle(request: req, response: res) { (args: Any...) in
      e.fulfill()
    }
    waitForExpectations(timeout: 3) { error in
      XCTAssertNil(error)
      XCTAssertTrue(didAwait)
    }
  }

  func testAsyncMiddlewareChaining() throws {
    let route = Route(id: "root")
    let e     = expectation(description: "chain completed")

    var order = [ Int ]()
    route.use(async { req, res, next in
      order.append(1)
      next()
    })
    route.use(async { req, res, next in
      order.append(2)
      next()
    })

    let req = IncomingMessage(url: "/hello")
    let res = TestServerResponse()

    try route.handle(request: req, response: res) { (args: Any...) in
      XCTAssertTrue(args.isEmpty)
      e.fulfill()
    }
    waitForExpectations(timeout: 3) { error in
      XCTAssertNil(error)
      XCTAssertEqual(order, [ 1, 2 ])
    }
  }

  // MARK: - AsyncFinalMiddleware (2-arg)

  func testAsyncFinalMiddleware() throws {
    let route = Route(id: "root")
    let e     = expectation(description: "final middleware ran")

    var didRun = false
    route.use(async { (req: IncomingMessage, res: ServerResponse) in
      didRun = true
      e.fulfill()
    })

    let req = IncomingMessage(url: "/hello")
    let res = TestServerResponse()

    var didCallNext = false
    try route.handle(request: req, response: res) { (args: Any...) in
      didCallNext = true
    }
    waitForExpectations(timeout: 3) { error in
      XCTAssertNil(error)
      XCTAssertTrue(didRun)
      XCTAssertFalse(didCallNext)
    }
  }

  func testAsyncFinalMiddlewareForwardsThrow() throws {
    enum TestError: Swift.Error, Equatable { case boom }

    let route = Route(id: "root")
    let e     = expectation(description: "error forwarded")

    var errorCatched: Swift.Error?
    route.use { error, req, res, next in
      errorCatched = error
      e.fulfill()
    }
    route.use(async { (req: IncomingMessage, res: ServerResponse) in
      throw TestError.boom
    })

    let req = IncomingMessage(url: "/hello")
    let res = TestServerResponse()

    try route.handle(request: req, response: res) { (args: Any...) in }

    waitForExpectations(timeout: 3) { error in
      XCTAssertNil(error, "timed out")
      XCTAssertNotNil(errorCatched)
      XCTAssert(errorCatched is TestError)
      if let err = errorCatched as? TestError {
        XCTAssertEqual(err, .boom)
      }
    }
  }

  func testAsyncFinalMiddlewareCanAwait() throws {
    let route = Route(id: "root")
    let e     = expectation(description: "final middleware ran")

    var didAwait = false
    route.use(async { (req: IncomingMessage, res: ServerResponse) in
      try await Task.sleep(nanoseconds: 1_000_000)
      didAwait = true
      e.fulfill()
    })

    let req = IncomingMessage(url: "/hello")
    let res = TestServerResponse()

    try route.handle(request: req, response: res) { (args: Any...) in }

    waitForExpectations(timeout: 3) { error in
      XCTAssertNil(error)
      XCTAssertTrue(didAwait)
    }
  }

  static var allTests = [
    ( "testAsyncMiddlewareCallsNext"          ,
      testAsyncMiddlewareCallsNext            ),
    ( "testAsyncMiddlewareDoesNotCallNext"    ,
      testAsyncMiddlewareDoesNotCallNext      ),
    ( "testAsyncMiddlewareForwardsThrowToNext",
      testAsyncMiddlewareForwardsThrowToNext  ),
    ( "testAsyncMiddlewareCanAwait"           ,
      testAsyncMiddlewareCanAwait             ),
    ( "testAsyncMiddlewareChaining"           ,
      testAsyncMiddlewareChaining             ),
    ( "testAsyncFinalMiddleware"              ,
      testAsyncFinalMiddleware                ),
    ( "testAsyncFinalMiddlewareForwardsThrow" ,
      testAsyncFinalMiddlewareForwardsThrow   ),
    ( "testAsyncFinalMiddlewareCanAwait"      ,
      testAsyncFinalMiddlewareCanAwait        ),
  ]
}
