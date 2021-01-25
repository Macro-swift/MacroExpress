import XCTest
import Macro
@testable import connect
import NIO


final class MultiPartParserTests: XCTestCase {
  
  func testSimpleFormData() throws {
    typealias fixture = Fixtures.SimpleFormData
    XCTAssertEqual(fixture.data[-2], 13)
    XCTAssertEqual(fixture.data[-1], 10)
    
    var parser = MultiPartParser(boundary: fixture.boundary)
    
    var events      = [ MultiPartParser.Event ]()
    var expectedIdx = 0
    parser.write(fixture.data) {
      print("EVENT[\(expectedIdx)]:", $0)
      events.append($0)
      if expectedIdx < fixture.expectedEvents.count {
        XCTAssertEqual($0, fixture.expectedEvents[expectedIdx])
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
    for i in 0..<(min(events.count, fixture.expectedEvents.count)) {
      XCTAssertEqual(events[i], fixture.expectedEvents[i])
    }
  }

  func testSimpleFormDataFragmented() throws {
    typealias fixture = Fixtures.SimpleFormData
    XCTAssertEqual(fixture.data[-2], 13)
    XCTAssertEqual(fixture.data[-1], 10)
    
    var parser = MultiPartParser(boundary: fixture.boundary)
    
    var events      = [ MultiPartParser.Event ]()
    var expectedIdx = 0
    
    func checkNextEvent(_ event: MultiPartParser.Event, isEnd: Bool = false) {
      print("\(isEnd ? "END-" : "")EVENT[\(expectedIdx)]:", event)
      events.append(event)
      if expectedIdx < fixture.expectedEvents.count {
        XCTAssertEqual(event, fixture.expectedEvents[expectedIdx])
        expectedIdx += 1
      }
    }
    
    let slices = [
      fixture.data.slice(  0,  1),
      fixture.data.slice(  1, 30),
      fixture.data.slice( 30, -10),
      fixture.data.slice(-10, -1),
      fixture.data.slice( -1)
    ]
    
    for slice in slices {
      parser.write(slice) { checkNextEvent($0) }
    }
    
    parser.end { checkNextEvent($0, isEnd: true) }
    XCTAssert(parser.buffer?.isEmpty ?? true)
    
    print("EVENTS:")
    XCTAssertFalse(events.isEmpty)
    for event in events {
      print("  -", event)
    }
    
    XCTAssertEqual(events.count, 5)
    for i in 0..<(min(events.count, fixture.expectedEvents.count)) {
      XCTAssertEqual(events[i], fixture.expectedEvents[i])
    }
  }
  
  static var allTests = [
    ( "testSimpleFormData"           , testSimpleFormData           ),
    ( "testSimpleFormDataFragmented" , testSimpleFormDataFragmented )
  ]
}

fileprivate enum Fixtures {

  enum SimpleFormData {
    static let boundary = "----WebKitFormBoundaryHU6Dqpfe9L4ATppg"
    static let data = Buffer(
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
    
    static let expectedEvents : [ MultiPartParser.Event ] = [
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
  }
}
