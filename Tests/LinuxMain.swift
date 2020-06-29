import XCTest
import mimeTests

var tests = [ XCTestCaseEntry ]()
tests += mimeTests.allTests()
XCTMain(tests)
