import XCTest
import MacroTestUtilities
import class http.IncomingMessage
import NIOHTTP1
@testable import express

final class VHostTests: XCTestCase, @unchecked Sendable {

  // MARK: - Helpers

  private func make(host: String, url: String = "/")
                    -> ( IncomingMessage, TestServerResponse )
  {
    var head = HTTPRequestHead(version: .init(major: 1, minor: 1),
                               method: .GET, uri: url)
    head.headers.add(name: "Host", value: host)
    return ( IncomingMessage(head), TestServerResponse() )
  }

  // MARK: - Glob matching

  func testGlobMatchesSubdomain() throws {
    var inner = false
    var fellThrough = false
    let mw = vhost("diary.*") { req, _, _ in
      inner = true
      XCTAssertEqual(req.vhost?.hostname, "diary.qa.zeezide.de")
      XCTAssertEqual(req.vhost?.pattern,  "diary.*")
      // `*` is non-greedy `.*?` so it captures the entire
      // suffix after the literal `diary.`
      XCTAssertEqual(req.vhost?.captures, [ "qa.zeezide.de" ])
    }
    let ( req, res ) = make(host: "diary.qa.zeezide.de")
    try mw(req, res) { _ in fellThrough = true }
    XCTAssertTrue (inner)
    XCTAssertFalse(fellThrough)
  }

  func testGlobIsCaseInsensitive() throws {
    var inner = false
    let mw = vhost("DIARY.*") { _, _, _ in inner = true }
    let ( req, res ) = make(host: "diary.qa.zeezide.de")
    try mw(req, res) { _ in }
    XCTAssertTrue(inner)
  }

  func testGlobMissesFallsThrough() throws {
    var inner = false
    var fellThrough = false
    let mw = vhost("dashboard.*") { _, _, _ in inner = true }
    let ( req, res ) = make(host: "diary.qa.zeezide.de")
    try mw(req, res) { _ in fellThrough = true }
    XCTAssertFalse(inner)
    XCTAssertTrue (fellThrough)
  }

  func testStarMatchesAcrossLabels() throws {
    // Mirrors Node `vhost`: `*` is `(?:.*?)`, matches across
    // labels. `*.example.com` matches both
    // foo.example.com and foo.bar.example.com.
    var oneLabel = false
    var twoLabel = false
    let mw1 = vhost("*.example.com") { req, _, _ in
      oneLabel = true
      XCTAssertEqual(req.vhost?.captures, [ "foo" ])
    }
    let mw2 = vhost("*.example.com") { req, _, _ in
      twoLabel = true
      XCTAssertEqual(req.vhost?.captures, [ "foo.bar" ])
    }

    let ( req1, res1 ) = make(host: "foo.example.com")
    try mw1(req1, res1) { _ in }
    let ( req2, res2 ) = make(host: "foo.bar.example.com")
    try mw2(req2, res2) { _ in }

    XCTAssertTrue(oneLabel)
    XCTAssertTrue(twoLabel)
  }

  func testExactStringMatchesExactly() throws {
    var matched = false
    var missed  = false
    let mw1 = vhost("example.com") { _, _, _ in matched = true }
    let mw2 = vhost("example.com") { _, _, _ in missed  = true }

    let ( req1, res1 ) = make(host: "example.com")
    try mw1(req1, res1) { _ in }
    let ( req2, res2 ) = make(host: "foo.example.com")
    try mw2(req2, res2) { _ in }

    XCTAssertTrue (matched)
    XCTAssertFalse(missed)
  }

  func testMultipleStarsCaptureInOrder() throws {
    var captures: [ String ] = []
    let mw = vhost("*.*.example.com") { req, _, _ in
      captures = req.vhost?.captures ?? []
    }
    let ( req, res ) = make(host: "a.b.example.com")
    try mw(req, res) { _ in }
    XCTAssertEqual(captures, [ "a", "b" ])
  }

  // MARK: - Port stripping

  func testHostWithPortStripped() throws {
    var hostname: String?
    let mw = vhost("diary.*") { req, _, _ in
      hostname = req.vhost?.hostname
    }
    let ( req, res ) = make(host: "diary.localhost:1339")
    try mw(req, res) { _ in }
    XCTAssertEqual(hostname, "diary.localhost")
  }

  func testIPv6BracketHostStripsPort() throws {
    // Drive several hosts through a catch-all vhost and read
    // back the port-stripped hostname via `req.vhost?.hostname`.
    let cases: [ ( host: String, expected: String ) ] = [
      ( "[::1]:8080", "[::1]"     ),
      ( "[fe80::1]",  "[fe80::1]" ),
      ( "foo:8080",   "foo"       ),
      ( "foo",        "foo"       )
    ]
    for ( host, expected ) in cases {
      var hostname: String?
      let mw = vhost("*") { req, _, _ in hostname = req.vhost?.hostname }
      let ( req, res ) = make(host: host)
      try mw(req, res) { _ in }
      XCTAssertEqual(hostname, expected, "host=\(host)")
    }
  }

  // MARK: - No Host header

  func testMissingHostHeaderFallsThrough() throws {
    var inner = false
    var fellThrough = false
    let mw = vhost("diary.*") { _, _, _ in inner = true }
    let req = IncomingMessage(.init(version: .init(major: 1, minor: 1),
                                    method: .GET, uri: "/"))
    let res = TestServerResponse()
    try mw(req, res) { _ in fellThrough = true }
    XCTAssertFalse(inner)
    XCTAssertTrue (fellThrough)
  }

  // MARK: - Regex overload

  func testRegexLiteralMatch() throws {
    var inner = false
    let mw = vhost(#/^(diary|tagebuch)\.example\.com$/#) { req, _, _ in
      inner = true
      XCTAssertEqual(req.vhost?.hostname, "tagebuch.example.com")
    }
    let ( req, res ) = make(host: "tagebuch.example.com")
    try mw(req, res) { _ in }
    XCTAssertTrue(inner)
  }

  func testRegexLiteralMissesFallsThrough() throws {
    var inner = false
    var fellThrough = false
    let mw = vhost(#/^(diary|tagebuch)\.example\.com$/#) { _, _, _ in
      inner = true
    }
    let ( req, res ) = make(host: "dashboard.example.com")
    try mw(req, res) { _ in fellThrough = true }
    XCTAssertFalse(inner)
    XCTAssertTrue (fellThrough)
  }

  // MARK: - MiddlewareObject overload (Express sub-app)

  func testMiddlewareObjectOverload() throws {
    let inner = express()
    var hit   = false
    inner.use { _, _, _ in hit = true }

    var fellThrough = false
    let mw = vhost("diary.*", inner)
    let ( req, res ) = make(host: "diary.localhost")
    try mw(req, res) { _ in fellThrough = true }
    XCTAssertTrue (hit)
    XCTAssertFalse(fellThrough)
  }

  // MARK: - Chaining: multiple vhosts in sequence

  func testChainedVHostsRouteByHost() throws {
    var hits = [ String ]()
    let diary     = vhost("diary.*")     { _, _, _ in hits.append("diary")     }
    let dashboard = vhost("dashboard.*") { _, _, _ in hits.append("dashboard") }

    // Sequence the two middlewares: if `diary` falls through,
    // try `dashboard`. We can't `try` inside the non-throwing
    // `Next`, so dispatch each middleware separately and use
    // a captured flag to gate the second.
    func dispatch(host: String) throws {
      let ( req, res ) = make(host: host)
      var firstHandled = true // assume handled until next() is called
      try diary(req, res) { _ in firstHandled = false }
      if !firstHandled {
        try dashboard(req, res) { _ in /* both fell through */ }
      }
    }
    try dispatch(host: "diary.qa.zeezide.de")
    try dispatch(host: "dashboard.qa.zeezide.de")
    try dispatch(host: "tasks.qa.zeezide.de") // none match
    XCTAssertEqual(hits, [ "diary", "dashboard" ])
  }

  static let allTests = [
    ( "testGlobMatchesSubdomain"          , testGlobMatchesSubdomain          ),
    ( "testGlobIsCaseInsensitive"         , testGlobIsCaseInsensitive         ),
    ( "testGlobMissesFallsThrough"        , testGlobMissesFallsThrough        ),
    ( "testStarMatchesAcrossLabels"       , testStarMatchesAcrossLabels       ),
    ( "testExactStringMatchesExactly"     , testExactStringMatchesExactly     ),
    ( "testMultipleStarsCaptureInOrder"   , testMultipleStarsCaptureInOrder   ),
    ( "testHostWithPortStripped"          , testHostWithPortStripped          ),
    ( "testIPv6BracketHostStripsPort"     , testIPv6BracketHostStripsPort     ),
    ( "testMissingHostHeaderFallsThrough" , testMissingHostHeaderFallsThrough ),
    ( "testRegexLiteralMatch"             , testRegexLiteralMatch             ),
    ( "testRegexLiteralMissesFallsThrough", testRegexLiteralMissesFallsThrough),
    ( "testMiddlewareObjectOverload"      , testMiddlewareObjectOverload      ),
    ( "testChainedVHostsRouteByHost"      , testChainedVHostsRouteByHost      )
  ]
}
