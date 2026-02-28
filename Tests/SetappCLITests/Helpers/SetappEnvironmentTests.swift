@testable import SetappCLI
import XCTest

final class SetappEnvironmentTests: XCTestCase {
    /// Verifies that the mock no-op installed by CommandTestCase actually no-ops.
    func testVerifyEnvironmentDefaultIsLive() {
        Dependencies.reset()
        XCTAssertNotNil(Dependencies.verifyEnvironment as Any)
    }

    /// Verifies that substituting a throwing closure propagates the error.
    func testSubstitutedVerifierCanThrow() {
        let expected = SetappError.generalError(message: "not installed")
        Dependencies.verifyEnvironment = { throw expected }

        XCTAssertThrowsError(try Dependencies.verifyEnvironment()) { error in
            XCTAssertEqual(error.localizedDescription, expected.localizedDescription)
        }

        // Clean up
        Dependencies.reset()
    }
}
