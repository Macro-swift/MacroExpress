import XCTest
@testable import DotEnv

final class DotEnvTests: XCTestCase {
    static var allTests = [
      ( "testConfig", testConfig )
    ]
    
    func testConfig() {
        let expected = [String: String]()
        XCTAssertEqual(try dotenv.tryConfig(), expected)
        XCTAssertEqual(dotenv.config(), expected)
    }
    
    func testParse() {
        let emptyString = ""
        XCTAssertEqual(dotenv.parse(emptyString),
                       [String: String](),
                       "Empty strings return an empty dictionary")
        
        let testString = """
       empty
       #comment - the next line is deliberately empty
       
       deja=vue
       bool=true
       int=42
       string=hello
       =
       deja=hello again!
       """
        let parsed = dotenv.parse(testString)
        XCTAssertEqual(parsed["empty"],
                       "",
                       "Value of an empty key is an empty String")
        XCTAssertEqual(parsed["bool"],
                       "true")
        XCTAssertEqual(parsed["deja"],
                       "vuehello again!",
                       "When the same key appears more than once its value is appended")
    }
}
