@testable import SetappCLI
import XCTest

final class SetappEnvironmentTests: XCTestCase {
    override func tearDown() {
        Dependencies.reset()
        super.tearDown()
    }

    /// Verifies that Dependencies.reset() restores verifyEnvironment to the live implementation.
    func testResetRestoresVerifyEnvironmentToLive() {
        // Install a sentinel so we can detect if it's called
        var sentinelRan = false
        Dependencies.verifyEnvironment = { sentinelRan = true }

        // Reset should replace the sentinel with the live implementation
        Dependencies.reset()

        // Call the restored verifier — the sentinel must NOT run
        _ = try? Dependencies.verifyEnvironment()
        XCTAssertFalse(sentinelRan, "Dependencies.reset() did not restore the live verifyEnvironment")
    }

    /// Verifies that substituting a throwing closure propagates the error.
    func testSubstitutedVerifierCanThrow() {
        let expected = SetappError.generalError(message: "not installed")
        Dependencies.verifyEnvironment = { throw expected }

        XCTAssertThrowsError(try Dependencies.verifyEnvironment()) { error in
            XCTAssertEqual(error as? SetappError, expected)
        }
    }
}
