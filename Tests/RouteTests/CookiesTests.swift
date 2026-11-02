//
//  CookiesTests.swift
//  MacroExpress
//
//  Created by Helge Heß on 02.11.26.
//

import XCTest
import MacroTestUtilities
@testable import http
@testable import connect

final class CookiesTests: XCTestCase {

  func testSettingTwoCookiesKeepsBoth() {
    let req = IncomingMessage(url: "/")
    let res = TestServerResponse()
    let cookies = Cookies(req, res)
    cookies.set("a", "1")
    cookies.set("b", "2")

    let values = res.headers["Set-Cookie"]
    XCTAssertEqual(values.count, 2)
    XCTAssertTrue(values.contains { $0.hasPrefix("a=1") })
    XCTAssertTrue(values.contains { $0.hasPrefix("b=2") })
  }

  func testSettingAgainAddsAHeader() {
    let req = IncomingMessage(url: "/")
    let res = TestServerResponse()
    let cookies = Cookies(req, res)
    cookies.set("a", "1")
    cookies.set("b", "2")
    cookies.set("a", "3")

    let values = res.headers["Set-Cookie"]
    XCTAssertEqual(values.count, 3)
    XCTAssertTrue(values[0].hasPrefix("a=1"))
    XCTAssertTrue(values[1].hasPrefix("b=2"))
    XCTAssertTrue(values[2].hasPrefix("a=3"), "The last one wins")
  }

  static let allTests = [
    ( "testSettingTwoCookiesKeepsBoth", testSettingTwoCookiesKeepsBoth ),
    ( "testSettingAgainAddsAHeader",    testSettingAgainAddsAHeader    )
  ]
}
