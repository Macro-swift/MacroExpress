import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [ XCTestCaseEntry ] {
  return [
    testCase(ErrorMiddlewareTests.allTests),
    testCase(SimpleRouteTests    .allTests)
  ]
}
#endif
