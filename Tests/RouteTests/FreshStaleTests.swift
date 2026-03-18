//
//  FreshStaleTests.swift
//  MacroExpress
//
//  Created by Helge Hess.
//  Copyright (C) 2026 ZeeZide GmbH. All rights reserved.
//

import XCTest
import MacroTestUtilities
import NIOHTTP1
@testable import http
@testable import express

final class FreshStaleTests: XCTestCase {

  private func runFreshCheck(method: HTTPMethod = .GET,
                             reqHeaders: HTTPHeaders = [:],
                             resStatus: Int = 200,
                             resHeaders: HTTPHeaders = [:])
              throws -> Bool
  {
    let app    = Express()
    var result = false

    app.get("/test") { req, res, next in
      res.statusCode = resStatus
      for (name, value) in resHeaders { res.setHeader(name, value) }
      result = req.fresh
      next()
    }

    let req = IncomingMessage(method: method, url: "/test",
                              headers: reqHeaders)
    let res = TestServerResponse()
    try app.handle(request: req, response: res) { _ in }
    app.clearAttachedState(request: req, response: res)
    return result
  }

  // MARK: - ETag

  func testMatchingETag() throws {
    let fresh = try runFreshCheck(reqHeaders: [ "If-None-Match": "\"abc123\"" ],
                                  resHeaders: [ "ETag": "\"abc123\"" ])
    XCTAssertTrue(fresh)
  }

  func testMismatchedETag() throws {
    let fresh = try runFreshCheck(reqHeaders: [ "If-None-Match": "\"abc123\"" ],
                                  resHeaders: [ "ETag": "\"xyz789\"" ])
    XCTAssertFalse(fresh)
  }

  func testWildcardETag() throws {
    let fresh = try runFreshCheck(reqHeaders: [ "If-None-Match": "*" ],
                                  resHeaders: [ "ETag": "\"anything\"" ])
    XCTAssertTrue(fresh)
  }

  func testWeakETagMatch() throws {
    let fresh = try runFreshCheck(reqHeaders: [ "If-None-Match": "W/\"abc\"" ],
                                  resHeaders: [ "ETag": "W/\"abc\"" ])
    XCTAssertTrue(fresh)
  }

  func testWeakVsStrongETagMatch() throws {
    let fresh = try runFreshCheck(reqHeaders: [ "If-None-Match": "W/\"abc\"" ],
                                  resHeaders: [ "ETag": "\"abc\"" ])
    XCTAssertTrue(fresh, "weak comparison should strip W/ prefix")
  }

  func testMultipleETags() throws {
    let fresh = try runFreshCheck(
      reqHeaders: [ "If-None-Match": "\"a\", \"b\", \"c\"" ],
      resHeaders: [ "ETag": "\"b\"" ]
    )
    XCTAssertTrue(fresh)
  }

  func testMultipleETagsNoMatch() throws {
    let fresh = try runFreshCheck(
      reqHeaders: [ "If-None-Match": "\"a\", \"b\"" ],
      resHeaders: [ "ETag": "\"c\"" ]
    )
    XCTAssertFalse(fresh)
  }

  // MARK: - Last-Modified

  func testMatchingLastModified() throws {
    let date = "Wed, 15 Mar 2026 12:00:00 GMT"
    let fresh = try runFreshCheck(reqHeaders: [ "If-Modified-Since": date ],
                                  resHeaders: [ "Last-Modified": date ])
    XCTAssertTrue(fresh)
  }

  func testMismatchedLastModified() throws {
    let fresh = try runFreshCheck(
      reqHeaders: [ "If-Modified-Since": "Wed, 15 Mar 2026 12:00:00 GMT" ],
      resHeaders: [ "Last-Modified":     "Thu, 16 Mar 2026 12:00:00 GMT" ]
    )
    XCTAssertFalse(fresh)
  }

  func testLastModifiedBeforeIfModifiedSince() throws {
    // Last-Modified is earlier than If-Modified-Since => fresh
    let fresh = try runFreshCheck(
      reqHeaders: [ "If-Modified-Since": "Thu, 16 Mar 2026 12:00:00 GMT" ],
      resHeaders: [ "Last-Modified":     "Wed, 15 Mar 2026 12:00:00 GMT" ]
    )
    XCTAssertTrue(fresh, "Last-Modified before If-Modified-Since is fresh")
  }

  // MARK: - Preconditions

  func testNotFreshForPOST() throws {
    let app = Express()
    var result = false
    app.post("/test") { req, res, next in
      res.setHeader("ETag", "\"abc\"")
      result = req.fresh
      next()
    }

    let req = IncomingMessage( method: .POST, url: "/test",
                               headers: [ "If-None-Match": "\"abc\"" ])
    let res = TestServerResponse()
    try app.handle(request: req, response: res) { _ in }
    app.clearAttachedState(request: req, response: res)

    XCTAssertFalse(result, "fresh should be false for POST")
  }

  func testNotFreshWithout304Or2xx() throws {
    let fresh = try runFreshCheck(reqHeaders: [ "If-None-Match": "\"abc\"" ],
                                  resStatus: 404,
                                  resHeaders: [ "ETag": "\"abc\"" ])
    XCTAssertFalse(fresh, "fresh requires 2xx or 304 status")
  }

  func testNotFreshWithoutConditionalHeaders() throws {
    let fresh = try runFreshCheck(resHeaders: [ "ETag": "\"abc\"" ])
    XCTAssertFalse(fresh, "fresh requires If-None-Match or If-Modified-Since")
  }

  func testNoResponseMeansStale() throws {
    let req = IncomingMessage(url: "/test")
    XCTAssertFalse(req.fresh)
    XCTAssertTrue(req.stale)
  }

  // MARK: - Multiple header lines

  func testMultipleIfNoneMatchHeaders() throws {
    let app = Express()
    var result = false

    app.get("/test") { req, res, next in
      res.setHeader("ETag", "\"c\"")
      result = req.fresh
      next()
    }

    var hdrs = HTTPHeaders()
    hdrs.add(name: "If-None-Match", value: "\"a\"")
    hdrs.add(name: "If-None-Match", value: "\"b\", \"c\"")
    let req = IncomingMessage(url: "/test", headers: hdrs)
    let res = TestServerResponse()
    try app.handle(request: req, response: res) { _ in }
    app.clearAttachedState(request: req, response: res)

    XCTAssertTrue(result, "match in second header line should count")
  }

  func testIfNoneMatchTakesPrecedence() throws {
    let date   = "Wed, 15 Mar 2026 12:00:00 GMT"
    let app    = Express()
    var result = false

    app.get("/test") { req, res, next in
      res.setHeader("ETag", "\"xyz\"")
      res.setHeader("Last-Modified", date)
      result = req.fresh
      next()
    }

    let req = IncomingMessage(url: "/test",
                              headers: [ "If-None-Match": "\"no-match\"",
                                         "If-Modified-Since": date ])
    let res = TestServerResponse()
    try app.handle(request: req, response: res) { _ in }
    app.clearAttachedState(request: req, response: res)

    XCTAssertFalse(result,
                   "If-Modified-Since must be ignored if If-None-Match is set")
  }

  // MARK: - stale

  func testStaleIsInverseOfFresh() throws {
    let app = Express()
    var freshVal = false
    var staleVal = false

    app.get("/test") { req, res, next in
      res.setHeader("ETag", "\"abc\"")
      freshVal = req.fresh
      staleVal = req.stale
      next()
    }

    let req = IncomingMessage(url: "/test",
                              headers: [ "If-None-Match": "\"abc\"" ])
    let res = TestServerResponse()
    try app.handle(request: req, response: res) { _ in }
    app.clearAttachedState(request: req, response: res)

    XCTAssertTrue(freshVal)
    XCTAssertFalse(staleVal)
    XCTAssertEqual(freshVal, !staleVal)
  }

  static let allTests = [
    ( "testMatchingETag",               testMatchingETag               ),
    ( "testMismatchedETag",             testMismatchedETag             ),
    ( "testWildcardETag",               testWildcardETag               ),
    ( "testWeakETagMatch",              testWeakETagMatch              ),
    ( "testWeakVsStrongETagMatch",      testWeakVsStrongETagMatch      ),
    ( "testMultipleETags",              testMultipleETags              ),
    ( "testMultipleETagsNoMatch",       testMultipleETagsNoMatch       ),
    ( "testMatchingLastModified",       testMatchingLastModified       ),
    ( "testMismatchedLastModified",     testMismatchedLastModified     ),
    ( "testNotFreshForPOST",            testNotFreshForPOST            ),
    ( "testNotFreshWithout304Or2xx",    testNotFreshWithout304Or2xx    ),
    ( "testNoResponseMeansStale",       testNoResponseMeansStale       ),
    ( "testMultipleIfNoneMatchHeaders", testMultipleIfNoneMatchHeaders ),
    ( "testIfNoneMatchTakesPrecedence", testIfNoneMatchTakesPrecedence ),
    ( "testLastModifiedBeforeIfModifiedSince",
      testLastModifiedBeforeIfModifiedSince ),
    ( "testStaleIsInverseOfFresh",      testStaleIsInverseOfFresh      ),
    ( "testNotFreshWithoutConditionalHeaders",
      testNotFreshWithoutConditionalHeaders )
  ]
}
