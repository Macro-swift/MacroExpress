import XCTest
import mimeTests
import dotenvTests
import RouteTests

var tests = [ XCTestCaseEntry ]()
tests += mimeTests  .allTests()
tests += dotenvTests.allTests()
tests += RouteTests .allTests()
XCTMain(tests)
