import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [ XCTestCaseEntry ] {
  return [
    testCase(bodyParserTests     .allTests),
    testCase(MultiPartParserTests.allTests)
  ]
}
#endif
