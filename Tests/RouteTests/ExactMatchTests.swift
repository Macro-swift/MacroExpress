import XCTest
import MacroTestUtilities
import class     http.IncomingMessage
import enum      NIOHTTP1.HTTPMethod
@testable import express

final class ExactMatchTests: XCTestCase {

  // MARK: - Method routes do exact matching

  func testGetRootDoesNotMatchSubpath() throws {
    let route = Route(id: "root")
    var didCallRoute = false
    route.get("/") { _, _, _ in didCallRoute = true }

    let req = IncomingMessage(url: "/foo")
    let res = TestServerResponse()

    var didCallNext = false
    try route.handle(request: req, response: res) { ( args : Any... ) in
      didCallNext = true
    }
    XCTAssertFalse(didCallRoute, "should not match /foo")
    XCTAssertTrue (didCallNext,  "should call next")
  }

  func testGetRootMatchesExactRoot() throws {
    let route = Route(id: "root")
    var didCallRoute = false
    route.get("/") { _, _, _ in didCallRoute = true }

    let req = IncomingMessage(url: "/")
    let res = TestServerResponse()

    var didCallNext = false
    try route.handle(request: req, response: res) { ( args : Any... ) in
      didCallNext = true
    }
    XCTAssertTrue (didCallRoute, "should match /")
    XCTAssertFalse(didCallNext,  "should not call next")
  }

  // MARK: - use() still does prefix matching

  func testUseRootMatchesSubpath() throws {
    let route = Route(id: "root")
    var didCallRoute = false
    route.use("/") { _, _, _ in didCallRoute = true }

    let req = IncomingMessage(url: "/foo")
    let res = TestServerResponse()

    try route.handle(request: req, response: res) { ( args : Any... ) in }
    XCTAssertTrue(didCallRoute, "use('/') should match /foo (prefix)")
  }

  // MARK: - all() does exact matching

  func testAllRootDoesNotMatchSubpath() throws {
    let route = Route(id: "root")
    var didCallRoute = false
    route.all("/") { _, _, _ in didCallRoute = true }

    let req = IncomingMessage(method: .POST, url: "/foo")
    let res = TestServerResponse()

    var didCallNext = false
    try route.handle(request: req, response: res) { ( args : Any... ) in
      didCallNext = true
    }
    XCTAssertFalse(didCallRoute, "all('/') should not match /foo")
    XCTAssertTrue(didCallNext, "should call next")
  }

  func testAllRootMatchesExactRoot() throws {
    let route = Route(id: "root")
    var didCallRoute = false
    route.all("/") { _, _, _ in didCallRoute = true }

    let req = IncomingMessage(method: .POST, url: "/")
    let res = TestServerResponse()

    var didCallNext = false
    try route.handle(request: req, response: res) { ( args : Any... ) in
      didCallNext = true
    }
    XCTAssertTrue(didCallRoute, "all('/') should match /")
    XCTAssertFalse(didCallNext, "should not call next")
  }

  func testAllMatchesAnyMethod() throws {
    let route = Route(id: "root")
    var callCount = 0
    route.all("/api") { _, _, _ in callCount += 1 }

    for method: HTTPMethod in [ .GET, .POST, .PUT, .DELETE ] {
      let req = IncomingMessage(method: method, url: "/api")
      let res = TestServerResponse()
      try route.handle(request: req, response: res) { _ in }
    }
    XCTAssertEqual(callCount, 4, "all should match every method")
  }

  func testAllWithWildcardMatchesSubpath() throws {
    let route = Route(id: "root")
    var didCallRoute = false
    route.all("/api/*") { _, _, _ in didCallRoute = true }

    let req = IncomingMessage(url: "/api/users/42")
    let res = TestServerResponse()

    try route.handle(request: req, response: res) { _ in }
    XCTAssertTrue(didCallRoute, "all with wildcard should match subpaths")
  }

  // MARK: - Wildcard still allows extra segments

  func testGetWildcardMatchesDeepPath() throws {
    let route = Route(id: "root")
    var didCallRoute = false
    route.get("/todos/*") { _, _, _ in didCallRoute = true }

    let req = IncomingMessage(url: "/todos/1/details")
    let res = TestServerResponse()

    try route.handle(request: req, response: res) { ( args : Any... ) in }
    XCTAssertTrue(didCallRoute, "wildcard should match extra segments")
  }

  // MARK: - Variable patterns exact match

  func testGetWithVariableDoesNotMatchExtra() throws {
    let route = Route(id: "root")
    var didCallRoute = false
    route.get("/users/:id") { _, _, _ in didCallRoute = true }

    let req = IncomingMessage(url: "/users/42/profile")
    let res = TestServerResponse()

    var didCallNext = false
    try route.handle(request: req, response: res) { ( args : Any... ) in
      didCallNext = true
    }
    XCTAssertFalse(didCallRoute, "should not match extra /profile")
    XCTAssertTrue(didCallNext, "should call next")
  }

  func testGetWithVariableMatchesExact() throws {
    let route = Route(id: "root")
    var didCallRoute = false
    route.get("/users/:id") { _, _, _ in didCallRoute = true }

    let req = IncomingMessage(url: "/users/42")
    let res = TestServerResponse()

    try route.handle(request: req, response: res) { ( args : Any... ) in }
    XCTAssertTrue(didCallRoute, "should match /users/42")
  }

  // MARK: - Mounted routes with exact matching

  func testMountedGetExactMatch() throws {
    let outerRoute = Route(id: "outer")
    var didCallRoute = false
    outerRoute.route("/admin")
      .get("/view") { _, _, _ in didCallRoute = true }

    let req = IncomingMessage(url: "/admin/view/extra")
    let res = TestServerResponse()

    var didCallNext = false
    try outerRoute.handle(request: req, response: res) { ( args : Any... ) in
      didCallNext = true
    }
    XCTAssertFalse(didCallRoute, "should not match /admin/view/extra")
    XCTAssertTrue(didCallNext, "should call next")
  }

  // MARK: - Parenthesized wildcard: path(*)

  func testParenWildcardMatchesExactPrefix() throws {
    let route = Route(id: "root")
    var didCallRoute = false
    route.get("/api(*)") { _, _, _ in didCallRoute = true }

    let req = IncomingMessage(url: "/api")
    let res = TestServerResponse()

    try route.handle(request: req, response: res) { _ in }
    XCTAssertTrue(didCallRoute, "/api(*) should match /api")
  }

  func testParenWildcardMatchesPrefixExtension() throws {
    let route = Route(id: "root")
    var didCallRoute = false
    route.get("/api(*)") { _, _, _ in didCallRoute = true }

    let req = IncomingMessage(url: "/api2")
    let res = TestServerResponse()

    try route.handle(request: req, response: res) { _ in }
    XCTAssertTrue(didCallRoute, "/api(*) should match /api2")
  }

  func testParenWildcardMatchesSubpath() throws {
    let route = Route(id: "root")
    var didCallRoute = false
    route.get("/api(*)") { _, _, _ in didCallRoute = true }

    let req = IncomingMessage(url: "/api/users")
    let res = TestServerResponse()

    try route.handle(request: req, response: res) { _ in }
    XCTAssertTrue(didCallRoute,"/api(*) should match /api/users")
  }

  func testParenWildcardMatchesDeepSubpath() throws {
    let route = Route(id: "root")
    var didCallRoute = false
    route.get("/api(*)") { _, _, _ in didCallRoute = true }

    let req = IncomingMessage(url: "/api/users/42/profile")
    let res = TestServerResponse()

    try route.handle(request: req, response: res) { _ in }
    XCTAssertTrue(didCallRoute, "/api(*) should match /api/users/42/profile")
  }

  func testParenWildcardDoesNotMatchDifferentPrefix() throws {
    let route = Route(id: "root")
    var didCallRoute = false
    route.get("/api(*)") { _, _, _ in didCallRoute = true }

    let req = IncomingMessage(url: "/web")
    let res = TestServerResponse()

    var didCallNext = false
    try route.handle(request: req, response: res) {
      ( args : Any... ) in didCallNext = true
    }
    XCTAssertFalse(didCallRoute, "/api(*) should not match /web")
    XCTAssertTrue(didCallNext, "should call next")
  }

  static let allTests = [
    ( "testGetRootDoesNotMatchSubpath",      testGetRootDoesNotMatchSubpath   ),
    ( "testGetRootMatchesExactRoot",         testGetRootMatchesExactRoot      ),
    ( "testUseRootMatchesSubpath",           testUseRootMatchesSubpath        ),
    ( "testAllRootDoesNotMatchSubpath",      testAllRootDoesNotMatchSubpath   ),
    ( "testAllRootMatchesExactRoot",         testAllRootMatchesExactRoot      ),
    ( "testAllMatchesAnyMethod",             testAllMatchesAnyMethod          ),
    ( "testAllWithWildcardMatchesSubpath",   testAllWithWildcardMatchesSubpath),
    ( "testGetWildcardMatchesDeepPath",      testGetWildcardMatchesDeepPath   ),
    ( "testGetWithVariableMatchesExact",     testGetWithVariableMatchesExact  ),
    ( "testMountedGetExactMatch",            testMountedGetExactMatch         ),
    ( "testGetWithVariableDoesNotMatchExtra", 
      testGetWithVariableDoesNotMatchExtra ),
    ( "testParenWildcardMatchesExactPrefix",
      testParenWildcardMatchesExactPrefix ),
    ( "testParenWildcardMatchesPrefixExtension",
      testParenWildcardMatchesPrefixExtension ),
    ( "testParenWildcardMatchesSubpath",
      testParenWildcardMatchesSubpath ),
    ( "testParenWildcardMatchesDeepSubpath",
      testParenWildcardMatchesDeepSubpath ),
    ( "testParenWildcardDoesNotMatchDifferentPrefix",
      testParenWildcardDoesNotMatchDifferentPrefix )
  ]
}
