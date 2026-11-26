//
//  CookiesTests.swift
//  MacroExpress
//
//  Created by Helge Heß on 02.11.26.
//

import XCTest
import MacroTestUtilities
import NIOHTTP1
@testable import http
@testable import connect

final class CookiesTests: XCTestCase {

  func testSettingTwoCookiesKeepsBoth() {
    let req = IncomingMessage(url: "/"), res = TestServerResponse()
    let cookies = Cookies(req, res)
    cookies.set("a", "1")
    cookies.set("b", "2")

    let values = res.headers["Set-Cookie"]
    XCTAssertEqual(values.count, 2)
    XCTAssertTrue(values.contains { $0.hasPrefix("a=1") })
    XCTAssertTrue(values.contains { $0.hasPrefix("b=2") })
  }

  func testSettingAgainAddsAHeader() {
    let req = IncomingMessage(url: "/"), res = TestServerResponse()
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

  func testTokenValuesStayAsIs() {
    // e.g. base64 CSRF tokens, read by JavaScript
    let v = "2iuwTMfo.FeknAYJB+cCi/pZ9=="
    XCTAssertEqual(Cookie.encodeValue(v), v)
  }

  func testInvalidCharactersAreEncoded() {
    XCTAssertEqual(Cookie.encodeValue("a b;c,\"d\\"),
                   "a%20b%3Bc%2C%22d%5C")
    XCTAssertEqual(Cookie.encodeValue("100%"), "100%25")
    XCTAssertEqual(Cookie.encodeValue("Gr\u{00FC}n"), "Gr%C3%BCn")
  }

  func testDecoding() {
    XCTAssertEqual(Cookie.decodeValue("a%20b%3Bc"),  "a b;c")
    XCTAssertEqual(Cookie.decodeValue("Gr%C3%BCn"),  "Gr\u{00FC}n")
    XCTAssertEqual(Cookie.decodeValue("\"quoted\""), "quoted")
    XCTAssertEqual(Cookie.decodeValue("50%zz"),      "50%zz", "invalid stays")
    XCTAssertEqual(Cookie.decodeValue("%FF"),        "%FF", "not UTF-8 stays")
    XCTAssertEqual(Cookie.decodeValue("plain"),      "plain")
  }

  func testValuesRoundTrip() {
    for v in [ "a b;c", "100%", "x=y&z", "Gr\u{00FC}n \u{1F600}", "" ] {
      XCTAssertEqual(Cookie.decodeValue(Cookie.encodeValue(v)), v)
    }
  }

  func testRequestCookiesAreDecoded() {
    let req = IncomingMessage(url: "/", 
                              headers: [ "Cookie":"a=x%20y; b=\"q\"; c=plain" ])
    let cookies = Cookies(req)
    XCTAssertEqual(cookies["a"], "x y")
    XCTAssertEqual(cookies["b"], "q")
    XCTAssertEqual(cookies["c"], "plain")
  }

  func testInvalidCookiesAreNotSet() {
    let res = TestServerResponse()
    let cookies = Cookies(IncomingMessage(url: "/"), res)
    cookies.set("bad name", "1")
    cookies.set(cookie: Cookie(name: "p", value: "1", path: "/;x"))
    cookies.set("good", "1")
    XCTAssertEqual(res.headers["Set-Cookie"].count, 1)
    XCTAssertTrue(res.headers["Set-Cookie"][0].hasPrefix("good=1"))
  }

  func testSecureConnectionDetection() {
    func secure(_ headers: [ ( String, String ) ]) -> Bool {
      var h = HTTPHeaders()
      for ( name, value ) in headers { h.add(name: name, value: value) }
      return Cookies(IncomingMessage(url: "/", headers: h))
        .isSecureConnection
    }
    XCTAssertTrue (secure([ ( "X-Forwarded-Proto", "https"              ) ]))
    XCTAssertTrue (secure([ ( "X-Forwarded-Proto", "https, http"        ) ]))
    XCTAssertFalse(secure([ ( "X-Forwarded-Proto", "http"               ) ]))
    XCTAssertFalse(secure([ ( "Host",              "portal.example.com" ) ]))
    XCTAssertTrue (secure([ ( "Host",              "localhost:1339"     ) ]))
    XCTAssertTrue (secure([ ( "Host",              "[::1]:1339"         ) ]))
    XCTAssertTrue (secure([ ( "Host",              "app.localhost"      ) ]))
    XCTAssertFalse(secure([ ( "Host",              "localhost.example.com" ) ]))
    XCTAssertTrue (secure([ ( "X-Forwarded-Proto", " HTTPS ,http"       ) ]))
    XCTAssertFalse(secure([ ( "X-Forwarded-Proto", "https2"             ) ]))
    XCTAssertFalse(secure([ ( "X-Forwarded-Proto", ""                   ) ]))
    XCTAssertTrue (secure([ ( "Host",              "LocalHost:80"       ) ]))
    XCTAssertTrue (secure([ ( "Host",              "127.0.0.1"          ) ]))
    XCTAssertTrue (secure([ ( "Host",              "App.Localhost:8080" ) ]))
    XCTAssertFalse(secure([ ( "Host",              "xlocalhost"         ) ]))
    XCTAssertFalse(secure([ ( "Host",              "[::2]:80"           ) ]))

    let forced = Cookies(IncomingMessage(url: "/"), secure: true)
    XCTAssertTrue(forced.isSecureConnection)
  }

  func testSecureCookieIsStillSetOnPlainHTTP() {
    // Only a warning is logged, the cookie is sent.
    let res = TestServerResponse()
    let req = IncomingMessage(url: "/",
                              headers: [ "Host": "portal.example.com" ])
    Cookies(req, res).set(cookie: Cookie(name: "s", value: "1", secure: true))
    XCTAssertEqual(res.headers["Set-Cookie"].count, 1)
  }
}
