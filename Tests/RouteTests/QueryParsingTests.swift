import XCTest
import MacroCore
import MacroTestUtilities
import connect
import express
import http

final class QueryParsingTests: XCTestCase, @unchecked Sendable {

  override class func setUp() {
    super.setUp()
    disableAtExitHandler()
  }

  func testScalarsKeepExistingDecodingAndLastValue() {
    let values = qs.parse("text=first&text=one+two%2Bthree&empty=&present")
    XCTAssertEqual(values["text"]    as? String, "one two+three")
    XCTAssertEqual(values["empty"]   as? String, "")
    XCTAssertEqual(values["present"] as? String, "")
  }

  func testNestedObjectsAndSparseArraysKeepExistingShape() throws {
    let values = qs.parse(
      "object[child][value]=a&rows[][value]=b&rows[][value]=c"
      + "&sparse[1]=old&sparse[3]=last&sparse[1]=new&sparse[]=appended",
      arrayLimit: 3
    )
    let nested = values["object"] as? [ String : [ String : String ] ]
    XCTAssertEqual(nested?["child"], [ "value": "a" ])
    
    let rows = values["rows"] as? [ [ String : String ] ]
    XCTAssertEqual(rows, [ [ "value": "b" ], [ "value": "c" ] ])
    
    let sparse = try XCTUnwrap(values["sparse"] as? [ Any ])
    XCTAssertEqual(sparse.map { $0 as? String },
                   [ nil, "new", nil, "last", "appended" ])
  }

  func testMalformedPairsLeaveNoPartialValues() {
    let query = "items[4][name]=ignored&object[child][unfinished=ignored"
              + "&object[leaf]suffix=ignored&[missing]=ignored&ok=yes"
    let values = qs.parse(query, arrayLimit: 3)
    XCTAssertEqual(values as? [ String : String ], [ "ok": "yes" ])
  }

  func testIndexedArrayBoundsAreCheckedBeforeSizing() throws {
    let values = qs.parse("outside[21]=ignored&inside[20]=accepted")
    XCTAssertNil(values["outside"])
    
    let inside = try XCTUnwrap(values["inside"] as? [ Any ])
    XCTAssertEqual(inside.count, 21)
    XCTAssertEqual(inside.last as? String, "accepted")

    let maximum  = String(Int.max)
    let overflow = maximum + "0"
    let form     = "maximum[\(maximum)]=ignored&overflow[\(overflow)]=ignored"
                 + "&ok=yes"
    let bounded = qs.parse(form, arrayLimit: Int.max)
    XCTAssertEqual(bounded as? [ String : String ], [ "ok": "yes" ])
  }

  func testConflictingShapesKeepTheFirstShapeAndAllowOtherWrites() {
    let query = "scalar=first&scalar[]=ignored&scalar=last"
              + "&array[]=first&array=ignored&array[name]=ignored&array[]=last"
              + "&object[name]=kept&object[]=ignored&object[other]=also-kept"
              + "&rows[0][name]=kept&rows[0]=ignored&rows[0][other]=also-kept"
    let values = qs.parse(query)
    XCTAssertEqual(values["scalar"] as? String, "last")
    XCTAssertEqual(values["array"] as? [ String ], [ "first", "last" ])
    
    let expected = [ "name": "kept", "other": "also-kept" ]
    XCTAssertEqual(values["object"] as? [ String : String ], expected)
    XCTAssertEqual(values["rows"] as? [ [ String : String ] ], [ expected ])
  }

  func testMountedQueryAndParamReadTheSameValues() throws {
    let route   = Route()
    let handled = expectation(description: "query route ran")
    
    route.get("/read/:kind") { req, _, _ in
      XCTAssertEqual(req.query["value"] as? String, "first")
      XCTAssertEqual(req.param("value") as? String, "first")
      XCTAssertEqual(req.query["kind"] as? String, "query")
      XCTAssertEqual(req.param("kind") as? String, "route")
      XCTAssertEqual(req.param("tags") as? [ String ], [ "a", "b" ])
      handled.fulfill()
    }
    let url = "/read/route?value=first&value[]=ignored&kind=query"
            + "&tags%5B%5D=a&tags%5B%5D=b"
    let req = IncomingMessage(url: url)
    try route.handle(request: req, response: TestServerResponse()) { _ in
      XCTFail("Request unexpectedly fell through")
    }
    
    wait(for: [ handled ], timeout: 3)
  }

  func testMountedDefaultFormParserKeepsScalarAndArrayValues() {
    let route   = Route()
    let handled = expectation(description: "form route ran")
    
    route.use(bodyParser.urlencoded())
    route.post("/form") { req, _, _ in
      guard case .urlEncoded(let values) = req.body else {
        XCTFail("Expected parsed form")
        handled.fulfill()
        return
      }
      
      XCTAssertEqual(values["value"]    as? String, "body+value")
      XCTAssertEqual(req.param("value") as? String, "body+value")
      XCTAssertEqual(values["tags"]     as? [ String ], [ "a", "b" ])
      XCTAssertNil(values["discarded"])
      handled.fulfill()
    }
    
    let req = IncomingMessage(
      method: .POST, url: "/form?value=query",
      headers: [ "Content-Type": "application/x-www-form-urlencoded" ]
    )
    let body = "value=body%2Bvalue&value[]=ignored&tags[]=a&tags[]=b"
             + "&discarded[23][name]=ignored"
    req.push(Buffer(body))
    req.push(nil)

    let res = TestServerResponse()
    MacroCore.shared.fallbackEventLoop().execute {
      do {
        try route.handle(request: req, response: res) { _ in
          XCTFail("Request unexpectedly fell through")
          handled.fulfill()
        }
      }
      catch {
        XCTFail("Request handling failed: \(error)")
        handled.fulfill()
      }
    }
    wait(for: [ handled ], timeout: 3)
  }
}
