//
//  RecursionTests.swift
//  MacroExpress
//
//  Created by Helge Hess.
//  Copyright (C) 2026 ZeeZide GmbH. All rights reserved.
//

import XCTest
import MacroTestUtilities
import class     http.IncomingMessage
@testable import connect
@testable import express

final class RecursionTests: XCTestCase {

  // Many middlewarez in a single Route, each calling `next()` synchronously. 
  func testManySequentialMiddleware() throws {
    let count = 5000
    let route = Route(id: "seq")
    for _ in 0..<count {
      route.use { _, _, next in next() }
    }
    var finalCalled = false
    route.use { _, _, _ in finalCalled = true }

    let req = IncomingMessage(url: "/hello")
    let res = TestServerResponse()

    var didCallNext = false
    try route.handle(request: req, response: res) { ( args: Any... ) in
      didCallNext = true
    }
    XCTAssertTrue (finalCalled, "final middleware should have been called")
    XCTAssertFalse(didCallNext,
                   "next should not be called (final does not call it)")
  }

  // Same as above but every middleware calls `next()`, so the chain completes 
  // and `upperNext` is reached.
  func testManyPassthroughMiddleware() throws {
    let count = 5000
    let route = Route(id: "pass")
    for _ in 0..<count {
      route.use { _, _, next in next() }
    }

    let req = IncomingMessage(url: "/hello")
    let res = TestServerResponse()

    var didCallNext = false
    try route.handle(request: req, response: res) { ( args: Any... ) in
      didCallNext = true
    }
    XCTAssertTrue(didCallNext,
                  "upperNext should be called after all pass-through")
  }

  // Deeply nested routes: each route mounts a child route at a sub-path.  
  func testDeepRouteNesting() throws {
    let depth = 200
    // Build /a/a/a/.../a chain
    var innermost: Route!
    let root = Route(id: "root")
    var current = root
    for i in 0..<depth {
      let child = Route(id: "child-\(i)", pattern: "/a")
      current.add(route: child)
      current = child
    }
    innermost = current

    var innermostCalled = false
    innermost.use { _, _, _ in innermostCalled = true }

    let url = "/" + String(repeating: "a/", count: depth).dropLast()
    let req = IncomingMessage(url: String(url))
    let res = TestServerResponse()

    var didCallNext = false
    try root.handle(request: req, response: res) { ( args: Any... ) in
      didCallNext = true
    }
    XCTAssertTrue(innermostCalled,
                  "innermost middleware should be reached")
    XCTAssertFalse(didCallNext,
                   "upperNext should not be called")
  }

  // Deep nesting where each level calls `next()` after its
  // child returns.  Verifies state restoration at each level.
  func testDeepNestingWithStateRestoration() throws {
    let depth = 100
    let root  = Route(id: "root")
    var current = root
    for i in 0..<depth {
      let child = Route(id: "level-\(i)", pattern: "/l")
      current.add(route: child)
      current = child
    }
    // Innermost calls next
    current.use { _, _, next in next() }

    let url = "/" + Array(repeating: "l", count: depth).joined(separator: "/")
    let req = IncomingMessage(url: url)
    let res = TestServerResponse()

    var didCallNext = false
    try root.handle(request: req, response: res) { ( args: Any... ) in
      didCallNext = true
    }
    XCTAssertTrue (didCallNext, "upperNext should be reached after full unwind")
    XCTAssertNil  (req.baseURL, "baseURL should be restored to nil")
    XCTAssertEqual(req.url, url, "url should be restored to original")
  }

  // A route with many child routes that don't match the request.
  func testManyNonMatchingRoutes() throws {
    let count = 5000
    let root  = Route(id: "root")

    // Register many routes that won't match
    for i in 0..<count {
      root.get("/nomatch-\(i)") { _, _, _ in
        XCTFail("non-matching route \(i) should not run")
      }
    }
    // Register one that does match
    var matched = false
    root.get("/target") { _, _, _ in matched = true }

    let req = IncomingMessage(url: "/target")
    let res = TestServerResponse()

    var didCallNext = false
    try root.handle(request: req, response: res) { ( args: Any... ) in
      didCallNext = true
    }
    XCTAssertTrue (matched,     "target route should match")
    XCTAssertFalse(didCallNext, "upperNext should not be called")
  }

  // Many non-matching routes followed by a matching one,
  // with method mismatch (GET routes, POST request).
  func testManyMethodMismatchRoutes() throws {
    let count = 5000
    let root  = Route(id: "root")

    for i in 0..<count {
      root.get("/path-\(i)") { _, _, _ in
        XCTFail("GET route \(i) should not run for POST")
      }
    }
    var matched = false
    root.post("/path-0") { _, _, _ in matched = true }

    let req = IncomingMessage(method: .POST, url: "/path-0")
    let res = TestServerResponse()

    try root.handle(request: req, response: res) { _ in }
    XCTAssertTrue(matched, "POST route should match")
  }

  // Error thrown at depth propagates through many error middlewarez without 
  // stack overflow.
  func testErrorPropagationThroughChain() throws {
    enum TestError: Error { case bang }

    let count = 2000
    let route = Route(id: "errors")

    // First middleware throws
    route.use { _, _, _ in throw TestError.bang }

    // Many error middleware that re-throw via next
    for _ in 0..<count {
      route.use { (error: Error, _, _, next: @escaping Next) in
        next(error)
      }
    }

    // Final error handler catches it
    var caughtError: Error?
    route.use { (error: Error, _, _, _: @escaping Next) in
      caughtError = error
    }

    let req = IncomingMessage(url: "/hello")
    let res = TestServerResponse()

    try route.handle(request: req, response: res) { _ in }
    XCTAssertNotNil(caughtError, "error should be caught")
    XCTAssert(caughtError is TestError, "error type should be preserved")
  }

  // Error thrown deep in nested routes propagates to error
  // middleware in parent route.
  func testErrorBubblesUpFromNestedRoute() throws {
    enum TestError: Error { case nested }

    let root = Route(id: "root")

    var caughtError: Error?
    root.use { (error: Error, _, _, _: @escaping Next) in
      caughtError = error
    }

    let child = Route(id: "child", pattern: "/deep")
    child.use { _, _, _ in throw TestError.nested }
    root.add(route: child)

    let req = IncomingMessage(url: "/deep")
    let res = TestServerResponse()

    try root.handle(request: req, response: res) { _ in }
    XCTAssertNotNil(caughtError, "error should bubble to parent")
    XCTAssert(caughtError is TestError, "error type should be preserved")
  }

  // MARK: - Connect Trampoline

  // Many middleware in Connect, each calling `next()`
  // synchronously.  Without the trampoline this overflows.
  func testConnectManyMiddleware() throws {
    let count = 5000
    let app   = Connect()

    var callCount = 0
    for _ in 0..<count {
      app.use { _, _, next in
        callCount += 1
        next()
      }
    }

    let req = IncomingMessage(url: "/hello")
    let res = TestServerResponse()

    app.doRequest(req, res)
    XCTAssertEqual(callCount, count, "all middleware should have been called")
  }

  // Connect middleware that throw should skip to the next middleware.
  func testConnectErrorSkipsMiddleware() throws {
    enum TestError: Error { case oops }

    let count = 1000
    let app   = Connect()

    var callCount = 0
    for _ in 0..<count {
      app.use { _, _, _ in
        callCount += 1
        throw TestError.oops
      }
    }

    let req = IncomingMessage(url: "/hello")
    let res = TestServerResponse()

    app.doRequest(req, res)
    XCTAssertEqual(callCount, count, "all middleware should run (each throws)")
  }

  // MARK: - Mixed Patterns

  // Nested routes with many sibling middleware at each level, some matching, 
  // some not.
  func testMixedNestedAndSequentialMiddleware() throws {
    let root = Route(id: "root")
    var callOrder = [ String ]()

    // 100 pass-through middleware at root level
    for _ in 0..<100 {
      root.use { _, _, next in next() }
    }

    // Mounted sub-route at /api
    let api = Route(id: "api", pattern: "/api")
    // 50 non-matching GET routes in /api
    for i in 0..<50 {
      api.get("/other-\(i)") { _, _, _ in
        XCTFail("should not match")
      }
    }
    // 100 pass-through middleware in /api
    for _ in 0..<100 {
      api.use { _, _, next in next() }
    }
    // Target route
    api.get("/target") { _, _, _ in
      callOrder.append("target")
    }
    root.add(route: api)

    // 100 more pass-through at root after /api
    for _ in 0..<100 {
      root.use { _, _, next in next() }
    }

    let req = IncomingMessage(url: "/api/target")
    let res = TestServerResponse()

    var didCallNext = false
    try root.handle(request: req, response: res) { ( args: Any... ) in
      didCallNext = true
    }
    XCTAssertEqual(callOrder, [ "target" ],
                   "target should be the only handler called")
    XCTAssertFalse(didCallNext, "final handler doesn't call next")
  }

  /**
   * Verify that the "route" / "router" signal skips remaining middleware within 
   * the same Route.
   *
   * Multiple middlewarez must be in the same Route (not separate sub-Routes 
   * created by `use`) for the signal to skip them.
   */
  func testRouteSignalSkipsRemaining() throws {
    var firstCalled = false
    let route = Route(id: "root", middleware: [
      { _, _, next in
        firstCalled = true
        next("route")
      },
      { _, _, _ in
        XCTFail("should be skipped by route signal")
      }
    ])

    let req = IncomingMessage(url: "/hello")
    let res = TestServerResponse()

    var didCallNext = false
    try route.handle(request: req, response: res) { ( args: Any... ) in
      didCallNext = true
    }
    XCTAssertTrue(firstCalled)
    XCTAssertTrue(didCallNext,
                  "route signal should pass to upperNext")
  }

  // Middleware order is preserved through the trampoline.
  func testMiddlewareOrderPreserved() throws {
    let count = 500
    let route = Route(id: "order")
    var order = [ Int ]()

    for i in 0..<count {
      let idx = i
      route.use { _, _, next in
        order.append(idx)
        next()
      }
    }

    let req = IncomingMessage(url: "/hello")
    let res = TestServerResponse()

    try route.handle(request: req, response: res) { _ in }
    XCTAssertEqual(order, Array(0..<count),"middleware should execute in order")
  }

  static let allTests = [
    ( "testManySequentialMiddleware"      , testManySequentialMiddleware      ),
    ( "testManyPassthroughMiddleware"     , testManyPassthroughMiddleware     ),
    ( "testDeepRouteNesting"              , testDeepRouteNesting              ),
    ( "testManyNonMatchingRoutes"         , testManyNonMatchingRoutes         ),
    ( "testManyMethodMismatchRoutes"      , testManyMethodMismatchRoutes      ),
    ( "testErrorPropagationThroughChain"  , testErrorPropagationThroughChain  ),
    ( "testErrorBubblesUpFromNestedRoute" , testErrorBubblesUpFromNestedRoute ),
    ( "testConnectManyMiddleware"         , testConnectManyMiddleware         ),
    ( "testConnectErrorSkipsMiddleware"   , testConnectErrorSkipsMiddleware   ),
    ( "testRouteSignalSkipsRemaining"     , testRouteSignalSkipsRemaining     ),
    ( "testMiddlewareOrderPreserved"      , testMiddlewareOrderPreserved      ),
    ( "testDeepNestingWithStateRestoration", 
      testDeepNestingWithStateRestoration ),
    ( "testMixedNestedAndSequentialMiddleware",
      testMixedNestedAndSequentialMiddleware ),
  ]
}
