import XCTest
import mimeTests
import routeTests
import dotenvTests

var tests = [ XCTestCaseEntry ]()
tests += mimeTests  .allTests()
tests += routeTests .allTests()
tests += dotenvTests.allTests()
XCTMain(tests)
