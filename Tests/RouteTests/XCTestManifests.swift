import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [ XCTestCaseEntry ] {
  return [
    testCase(AsyncMiddlewareTests .allTests),
    testCase(ErrorMiddlewareTests.allTests),
    testCase(SimpleRouteTests    .allTests),
    testCase(RouteMountingTests  .allTests)
  ]
}
#endif
