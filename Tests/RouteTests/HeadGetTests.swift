import XCTest
import MacroTestUtilities
import class     http.IncomingMessage
import enum      NIOHTTP1.HTTPMethod
@testable import express

/**
 * Express.js style: a route registered for `GET` should also serve `HEAD`
 * requests, but the response body is suppressed and only `Content-Length`
 * reflects the would-be body size.
 */
final class HeadGetTests: XCTestCase, @unchecked Sendable {

  func testHeadRequestMatchesGetRoute() throws {
    let route = Route(id: "root")
    var didCallRoute = false
    route.get("/foo") { _, _, _ in didCallRoute = true }

    let req = IncomingMessage(method: .HEAD, url: "/foo")
    let res = TestServerResponse()

    var didCallNext = false
    try route.handle(request: req, response: res) { ( args : Any... ) in
      didCallNext = true
    }
    XCTAssertTrue (didCallRoute, "HEAD should reach GET handler")
    XCTAssertFalse(didCallNext,  "next should not be called")
  }

  func testGetRequestStillMatchesGetRoute() throws {
    let route = Route(id: "root")
    var didCallRoute = false
    route.get("/foo") { _, _, _ in didCallRoute = true }

    let req = IncomingMessage(method: .GET, url: "/foo")
    let res = TestServerResponse()

    try route.handle(request: req, response: res) { _ in }
    XCTAssertTrue(didCallRoute, "GET should still reach GET handler")
  }

  func testPostRouteDoesNotMatchHead() throws {
    let route = Route(id: "root")
    var didCallRoute = false
    route.post("/foo") { _, _, _ in didCallRoute = true }

    let req = IncomingMessage(method: .HEAD, url: "/foo")
    let res = TestServerResponse()

    var didCallNext = false
    try route.handle(request: req, response: res) { ( args : Any... ) in
      didCallNext = true
    }
    XCTAssertFalse(didCallRoute, "HEAD should not match POST routes")
    XCTAssertTrue (didCallNext,  "next should be called")
  }

  func testExplicitHeadRouteStillMatches() throws {
    let route = Route(id: "root")
    var didCallRoute = false
    route.head("/foo") { _, _, _ in didCallRoute = true }

    let req = IncomingMessage(method: .HEAD, url: "/foo")
    let res = TestServerResponse()

    try route.handle(request: req, response: res) { _ in }
    XCTAssertTrue(didCallRoute, "explicit HEAD route should match HEAD")
  }

  func testHeadResponseDropsBodyButSetsContentLength() throws {
    let route = Route(id: "root")
    route.get("/foo") { _, res, _ in
      res.write("Hello")
      res.write(", world!")
      res.end()
    }

    let req = IncomingMessage(method: .HEAD, url: "/foo")
    let res = TestServerResponse()
    res.isHead = true

    try route.handle(request: req, response: res) { _ in }

    XCTAssertTrue(res.writtenContent.isEmpty,
                  "HEAD response must not capture a body")
    XCTAssertEqual(res.headBodyBytes, 13,
                   "HEAD must count would-be body bytes")
    let cl = res.headers["Content-Length"].first
    XCTAssertEqual(cl, "13", "Content-Length should reflect body size")
  }

  func testHeadResponseRespectsExplicitContentLength() throws {
    let route = Route(id: "root")
    route.get("/foo") { _, res, _ in
      res.setHeader("Content-Length", "42")
      res.write("Hello")
      res.end()
    }

    let req = IncomingMessage(method: .HEAD, url: "/foo")
    let res = TestServerResponse()
    res.isHead = true

    try route.handle(request: req, response: res) { _ in }

    XCTAssertTrue(res.writtenContent.isEmpty)
    let cl = res.headers["Content-Length"].first
    XCTAssertEqual(cl, "42",
                   "explicit Content-Length must not be overwritten")
  }

  static let allTests = [
    ( "testHeadRequestMatchesGetRoute",
      testHeadRequestMatchesGetRoute ),
    ( "testGetRequestStillMatchesGetRoute",
      testGetRequestStillMatchesGetRoute ),
    ( "testPostRouteDoesNotMatchHead",
      testPostRouteDoesNotMatchHead ),
    ( "testExplicitHeadRouteStillMatches",
      testExplicitHeadRouteStillMatches ),
    ( "testHeadResponseDropsBodyButSetsContentLength",
      testHeadResponseDropsBodyButSetsContentLength ),
    ( "testHeadResponseRespectsExplicitContentLength",
      testHeadResponseRespectsExplicitContentLength )
  ]
}
