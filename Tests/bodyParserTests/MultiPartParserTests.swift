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
    
    XCTAssertEqual(events.count, fixture.expectedEvents.count)
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
    
    XCTAssertEqual(events.count, fixture.expectedEvents.count)
    for i in 0..<(min(events.count, fixture.expectedEvents.count)) {
      XCTAssertEqual(events[i], fixture.expectedEvents[i])
    }
  }
  
  func testImageSubmitData() throws {
    typealias fixture = Fixtures.ImageSubmitData
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
    
    XCTAssertEqual(events.count, fixture.expectedEvents.count)
    for i in 0..<(min(events.count, fixture.expectedEvents.count)) {
      XCTAssertEqual(events[i], fixture.expectedEvents[i])
    }
  }
  
  func testTwoFileSubmit() throws {
    typealias fixture = Fixtures.TwoFilesSubmit
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
    
    XCTAssertEqual(events.count, fixture.expectedEvents.count)
    for i in 0..<(min(events.count, fixture.expectedEvents.count)) {
      XCTAssertEqual(events[i], fixture.expectedEvents[i])
    }
  }

  static var allTests = [
    ( "testSimpleFormData"           , testSimpleFormData           ),
    ( "testSimpleFormDataFragmented" , testSimpleFormDataFragmented ),
    ( "testImageSubmitData"          , testImageSubmitData          ),
    ( "testTwoFileSubmit"            , testTwoFileSubmit            )
  ]
}
