import XCTest
@testable import mime

final class mimeTests: XCTestCase {
  
  func testLookup() throws {
    XCTAssert(mime.lookup("json")       == "application/json; charset=UTF-8")
    XCTAssert(mime.lookup("index.html") == "text/html; charset=UTF-8")
  }

  static var allTests = [
    ( "testLookup", testLookup ),
  ]
}
