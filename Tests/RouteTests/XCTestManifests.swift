import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [ XCTestCaseEntry ] {
  return [
    testCase(AsyncMiddlewareTests      .allTests),
    testCase(ErrorMiddlewareTests      .allTests),
    testCase(SimpleRouteTests          .allTests),
    testCase(RouteMountingTests        .allTests),
    testCase(ExactMatchTests           .allTests),
    testCase(ClearAttachedStateTests   .allTests),
    testCase(FreshStaleTests           .allTests)
  ]
}
#endif
