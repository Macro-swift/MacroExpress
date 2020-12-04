import XCTest
import mimeTests
import routeTests

var tests = [ XCTestCaseEntry ]()
tests += mimeTests.allTests()
tests += routeTests.allTests()
XCTMain(tests)
