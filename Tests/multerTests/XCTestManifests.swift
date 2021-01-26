import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [ XCTestCaseEntry ] {
  return [
    testCase(MultiPartParserTests.allTests),
    testCase(multerTests         .allTests)
  ]
}
#endif
