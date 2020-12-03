import XCTest
import mimeTests
import routeTests
import DotEnvTests

var tests = [ XCTestCaseEntry ]()
tests += mimeTests.allTests()
tests += routeTests.allTests()
tests += DotEnvTests.allTests

XCTMain(tests)
