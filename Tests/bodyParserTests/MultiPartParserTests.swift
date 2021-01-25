import XCTest
import Macro
@testable import connect
import NIO

final class MultiPartParserTests: XCTestCase {
  
  func testSimpleFormData() throws {
    let boundary = "----WebKitFormBoundaryHU6Dqpfe9L4ATppg"

    let requestBody = Buffer(
      """
      --\(boundary)\r
      Content-Disposition: form-data; name="title"\r
      \r
      file.csv\r
      --\(boundary)\r
      Content-Disposition: form-data; name="file"; filename=""\r
      Content-Type: application/octet-stream\r
      \r
      \r
      --\(boundary)--\r\n
      """
    )
    XCTAssertEqual(requestBody[-2], 13)
    XCTAssertEqual(requestBody[-1], 10)

    let expectedEvents : [ MultiPartParser.Event ] = [
      .startPart([
        ( "Content-Disposition" , "form-data; name=\"title\"" )
      ]),
      .bodyData(Buffer("file.csv")),
      .endPart,
      .startPart([
        ( "Content-Disposition" , "form-data; name=\"file\"; filename=\"\"" ),
        ( "Content-Type"        , "application/octet-stream" )
      ]),
      .endPart
    ]
    
    var events = [ MultiPartParser.Event ]()
    
    var expectedIdx = 0
    var parser = MultiPartParser(boundary: boundary)
    parser.write(requestBody) {
      print("EVENT[\(expectedIdx)]:", $0)
      events.append($0)
      if expectedIdx < expectedEvents.count {
        XCTAssertEqual($0, expectedEvents[expectedIdx])
        expectedIdx += 1
      }
    }
    parser.end {
      print("END EVENT:", $0)
      events.append($0)
      XCTAssert(false, "unexpected event in end") // should be empty
    }
    XCTAssert(parser.buffer?.isEmpty ?? true)
    
    print("EVENTS:")
    XCTAssertFalse(events.isEmpty)
    for event in events {
      print("  -", event)
    }
    
    XCTAssertEqual(events.count, 5)
    for i in 0..<(min(events.count, expectedEvents.count)) {
      XCTAssertEqual(events[i], expectedEvents[i])
    }
  }

  static var allTests = [
    ( "testSimpleFormData" , testSimpleFormData ),
  ]
}

fileprivate extension Array {
  
  subscript(opt index: Int) -> Element? {
    guard index >= 0 && index < count else { return nil }
    return self[index]
  }
}
