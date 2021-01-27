import XCTest
import mimeTests
import dotenvTests
import RouteTests
import multerTests

var tests = [ XCTestCaseEntry ]()
tests += mimeTests  .allTests()
tests += dotenvTests.allTests()
tests += RouteTests .allTests()
tests += multerTests.allTests()
XCTMain(tests)
