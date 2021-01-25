import XCTest
import Macro
@testable import connect
import NIO

final class MultiPartParserTests: XCTestCase {
  
  func testSimpleFormData() throws {
    let boundary = "----WebKitFormBoundaryHU6Dqpfe9L4ATppg"
    
    let part1Header = [
      ( "Content-Disposition" , "form-data; name=\"title\"" )
    ]
    let part1Value = Buffer("file.csv")
    
    let part2Header = [
      ( "Content-Disposition" , "form-data; name=\"file\"; filename=\"\"" ),
      ( "Content-Type"        , "application/octet-stream" )
    ]
    let part2Value = Buffer()

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
      --\(boundary)--\r
      """
    )
    
    var events = [ MultiPartParser.Event ]()
    
    var parser = MultiPartParser(boundary: boundary)
    parser.write(requestBody) {
      events.append($0)
    }
    parser.end {
      events.append($0)
    }
    
    print("EVENTS:")
    XCTAssertFalse(events.isEmpty)
    for event in events {
      print("  -", event)
    }
    
    XCTAssertEqual(events.count, 6)
    XCTAssertEqual(events[opt: 0], .startPart(part1Header))
    XCTAssertEqual(events[opt: 1], .bodyData(part1Value))
    XCTAssertEqual(events[opt: 2], .endPart)
    XCTAssertEqual(events[opt: 3], .startPart(part2Header))
    XCTAssertEqual(events[opt: 4], .bodyData(part2Value))
    XCTAssertEqual(events[opt: 5], .endPart)
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
