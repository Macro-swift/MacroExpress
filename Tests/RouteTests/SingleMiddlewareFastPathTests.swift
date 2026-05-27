//
//  SingleMiddlewareFastPathTests.swift
//  MacroExpress
//

import XCTest
import MacroTestUtilities
import class    http.IncomingMessage
import enum    NIOHTTP1.HTTPMethod
@testable import connect
@testable import express

final class SingleMiddlewareFastPathTests: XCTestCase, @unchecked Sendable {

  // MARK: - next() shapes

  // Middleware calls next() with no args, upperNext must be invoked with no 
  // args too.
  func testNextNoArgs() throws {
    let route = Route(id: "next-noargs")
    route.use { _, _, next in next() }

    let req = IncomingMessage(url: "/x")
    let res = TestServerResponse()

    var upperArgs : [ Any ]?
    try route.handle(request: req, response: res) { (args: Any...) in 
      upperArgs = args
    }
    XCTAssertNotNil(upperArgs)
    XCTAssertEqual(upperArgs?.count, 0)
  }

  // Middleware calls next("route"), the walker
  // *consumes* this and calls upperNext with no args.
  // (It signals "skip remaining middleware in this
  // route", but with single-middleware there's nothing
  // to skip; result is the same as next().)
  func testNextRouteSkip() throws {
    let route = Route(id: "next-route")
    route.use { _, _, next in next("route") }

    let req = IncomingMessage(url: "/x")
    let res = TestServerResponse()

    var upperArgs : [ Any ]?
    try route.handle(request: req, response: res) { (args: Any...) in
      upperArgs = args
    }
    XCTAssertNotNil(upperArgs)
    XCTAssertEqual(upperArgs?.count, 0,
                   "'route' arg should be consumed, upperNext called with none")
  }

  // Middleware calls next("router"), same handling as next("route") at this 
  // dispatch level.
  func testNextRouterSkip() throws {
    let route = Route(id: "next-router")
    route.use { _, _, next in next("router") }

    let req = IncomingMessage(url: "/x")
    let res = TestServerResponse()

    var upperArgs : [ Any ]?
    try route.handle(request: req, response: res) { (args: Any...) in
      upperArgs = args
    }
    XCTAssertNotNil(upperArgs)
    XCTAssertEqual(upperArgs?.count, 0)
  }

  // Middleware calls next(error) -- error must propagate to upperNext (no 
  // error-middleware installed).
  func testNextWithError() throws {
    struct Boom: Swift.Error {}
    let route = Route(id: "next-err")
    route.use { _, _, next in next(Boom()) }

    let req = IncomingMessage(url: "/x")
    let res = TestServerResponse()

    var upperArgs : [ Any ]?
    try route.handle(request: req, response: res) { (args: Any...) in
      upperArgs = args
    }
    XCTAssertNotNil(upperArgs)
    XCTAssertEqual(upperArgs?.count, 1)
    XCTAssertTrue(upperArgs?.first is Boom)
  }

  // Middleware throws synchronously, error must surface as next-with-error to 
  // upperNext, NOT as a re-thrown Swift error from `route.handle`.
  func testMiddlewareThrows() throws {
    struct Kaboom: Swift.Error {}
    let route = Route(id: "throws")
    route.use { _, _, _ in throw Kaboom() }

    let req = IncomingMessage(url: "/x")
    let res = TestServerResponse()

    var upperArgs : [ Any ]?
    try route.handle(request: req, response: res) { (args: Any...) in
      upperArgs = args
    }
    XCTAssertNotNil(upperArgs)
    XCTAssertEqual(upperArgs?.count, 1)
    XCTAssertTrue(upperArgs?.first is Kaboom)
  }

  // Middleware never calls next, doesn't throw, upperNext should NOT be called
  // (request handled).
  func testMiddlewareTerminates() throws {
    let route = Route(id: "term")
    var ranMW = false
    route.use { _, _, _ in ranMW = true }

    let req = IncomingMessage(url: "/x")
    let res = TestServerResponse()

    var didCallUpper = false
    try route.handle(request: req, response: res) { _ in didCallUpper = true }
    XCTAssertTrue(ranMW)
    XCTAssertFalse(didCallUpper,
                   "upperNext must not fire when middleware terminates")
  }

  // Middleware calls next() twice, defensive: the walker only honors the first 
  // call. Fast path must do the same to preserve the once-only contract.
  func testNextCalledTwice() throws {
    let route = Route(id: "twice")
    route.use { _, _, next in
      next()
      next()
    }

    let req = IncomingMessage(url: "/x")
    let res = TestServerResponse()

    var upperCount = 0
    try route.handle(request: req, response: res) { _ in upperCount += 1 }
    XCTAssertEqual(upperCount, 1,
                   "upperNext must fire once even if mw calls next twice")
  }

  // MARK: - State save/restore

  // Pattern matches; middleware mutates url.
  // After dispatch the original url must be restored
  // (so upperNext sees the original).
  func testURLRestoredAfterDispatch() throws {
    let route = Route(id: "url-restore", pattern: "/api", method: nil)
    route.use { req, _, next in
      // Inside the route, url is rewritten to the
      // suffix after the matched prefix.
      next()
    }

    let req = IncomingMessage(url: "/api/hello")
    let res = TestServerResponse()

    let originalURL = req.url
    var afterURL : String?
    try route.handle(request: req, response: res) { _ in afterURL = req.url }
    XCTAssertEqual(afterURL, originalURL,
                   "request.url must be restored after dispatch")
  }

  // Path params populated during pattern match.
  func testParamsPopulated() throws {
    let route = Route(id: "params",
                      pattern: "/users/:id",
                      method: nil)
    var seenID : String?
    route.use { req, _, next in
      seenID = req.params["id"]
      next()
    }

    let req = IncomingMessage(url: "/users/42")
    let res = TestServerResponse()

    var didCallUpper = false
    try route.handle(request: req, response: res) { _ in didCallUpper = true }
    XCTAssertEqual(seenID, "42")
    XCTAssertTrue(didCallUpper)
  }

  // Method mismatch -- fast path must NOT activate
  // and must call upperNext immediately.
  func testMethodMismatchFallsThrough() throws {
    let route = Route(id: "post-only", pattern: nil, method: .POST)
    var ranMW = false
    route.use { _, _, _ in ranMW = true }

    let req = IncomingMessage(url: "/x")  // default GET
    let res = TestServerResponse()

    var didCallUpper = false
    try route.handle(request: req, response: res)
    { _ in didCallUpper = true }
    XCTAssertFalse(ranMW)
    XCTAssertTrue(didCallUpper,
      "method mismatch should fall through to upperNext")
  }

  // Pattern mismatch -- same as method mismatch.
  func testPatternMismatchFallsThrough() throws {
    let route = Route(id: "pat",
                      pattern: "/api",
                      method: nil)
    var ranMW = false
    route.use { _, _, _ in ranMW = true }

    let req = IncomingMessage(url: "/other/path")
    let res = TestServerResponse()

    var didCallUpper = false
    try route.handle(request: req, response: res)
    { _ in didCallUpper = true }
    XCTAssertFalse(ranMW)
    XCTAssertTrue(didCallUpper,
      "pattern mismatch should fall through to upperNext")
  }

  // MARK: - Subrouter (entry is a Route)

  // Single entry that IS a Route (not just a closure).
  // This exercises the `routeObjects[0] != nil` branch
  // of the fast path.
  func testSingleSubrouterEntry() throws {
    let inner = Route(id: "inner")
    var ranInner = false
    inner.use { _, _, next in
      ranInner = true
      next()
    }

    let outer = Route(id: "outer")
    outer.add(route: inner)

    let req = IncomingMessage(url: "/x")
    let res = TestServerResponse()

    var didCallUpper = false
    try outer.handle(request: req, response: res) { _ in didCallUpper = true }
    XCTAssertTrue(ranInner)
    XCTAssertTrue(didCallUpper)
  }

  // MARK: - Async middleware

  // Middleware that defers `next()` to a later event-loop tick (closure 
  // escapes synchronous return). Fast path must keep state alive until
  // the closure fires.
  func testAsyncNext() throws {
    let route = Route(id: "async")
    var ranMW = false
    let queue = DispatchQueue(label: "test.async-next")
    let sema  = DispatchSemaphore(value: 0)

    route.use { _, _, next in
      ranMW = true
      queue.asyncAfter(deadline: .now() + .milliseconds(20)) {
        next()
      }
    }

    let req = IncomingMessage(url: "/x")
    let res = TestServerResponse()

    var didCallUpper = false
    try route.handle(request: req, response: res) { _ in
      didCallUpper = true
      sema.signal()
    }
    XCTAssertTrue(ranMW)
    // upperNext fires async; wait for it.
    let waited = sema.wait(timeout: .now() + .seconds(2))
    XCTAssertEqual(waited, .success,
                   "upperNext was not called async within timeout")
    XCTAssertTrue(didCallUpper)
  }

  // MARK: - Allocations

  static let allTests = [
    ( "testNextNoArgs",                  testNextNoArgs                  ),
    ( "testNextRouteSkip",               testNextRouteSkip               ),
    ( "testNextRouterSkip",              testNextRouterSkip              ),
    ( "testNextWithError",               testNextWithError               ),
    ( "testMiddlewareThrows",            testMiddlewareThrows            ),
    ( "testMiddlewareTerminates",        testMiddlewareTerminates        ),
    ( "testNextCalledTwice",             testNextCalledTwice             ),
    ( "testURLRestoredAfterDispatch",    testURLRestoredAfterDispatch    ),
    ( "testParamsPopulated",             testParamsPopulated             ),
    ( "testMethodMismatchFallsThrough",  testMethodMismatchFallsThrough  ),
    ( "testPatternMismatchFallsThrough", testPatternMismatchFallsThrough ),
    ( "testSingleSubrouterEntry",        testSingleSubrouterEntry        ),
    ( "testAsyncNext",                   testAsyncNext                   )
  ]
}
