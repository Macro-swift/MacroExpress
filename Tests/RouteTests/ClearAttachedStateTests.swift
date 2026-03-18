//
//  ClearAttachedStateTests.swift
//  MacroExpress
//
//  Created by Helge Hess.
//  Copyright (C) 2026 ZeeZide GmbH. All rights reserved.
//

import XCTest
import MacroTestUtilities
@testable import http
@testable import express

final class ClearAttachedStateTests: XCTestCase {

  func testClearAttachedStateBreaksCycles() throws {
    let app = Express()

    weak var weakReq : IncomingMessage?
    weak var weakRes : TestServerResponse?

    var capturedReqResponse : ServerResponse?
    var capturedResRequest  : IncomingMessage?
    var capturedReqApp      : Express?

    app.use { req, res, next in
      capturedReqResponse = req.response
      capturedResRequest  = res.request
      capturedReqApp      = req.app
      next()
    }

    do {
      let req = IncomingMessage(url: "/hello")
      let res = TestServerResponse()
      weakReq = req
      weakRes = res

      try app.handle(request: req, response: res) { _ in }

      XCTAssertTrue(capturedResRequest === req,
                    "res.request should be req")
      XCTAssertTrue(capturedReqResponse === res,
                    "req.response should be res")
      XCTAssertTrue(capturedReqApp === app,
                    "req.app should be app")

      capturedReqResponse = nil
      capturedResRequest  = nil
      capturedReqApp      = nil

      app.clearAttachedState(request: req, response: res)

      XCTAssertNil(res.request,
                   "res.request should be cleared")
      XCTAssertNil(req.response,
                   "req.response should be cleared")
      XCTAssertNil(req.app,
                   "req.app should be cleared")
    }

    XCTAssertNil(weakReq,
                 "IncomingMessage should be deallocated")
    XCTAssertNil(weakRes,
                 "ServerResponse should be deallocated")
  }

  static let allTests = [
    ( "testClearAttachedStateBreaksCycles",
      testClearAttachedStateBreaksCycles )
  ]
}
