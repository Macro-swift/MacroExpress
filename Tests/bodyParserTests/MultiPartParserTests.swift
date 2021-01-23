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
    
    print("EVENTS:", events)
    XCTAssertFalse(events.isEmpty)
  }

  static var allTests = [
    ( "testSimpleFormData" , testSimpleFormData ),
  ]
}
