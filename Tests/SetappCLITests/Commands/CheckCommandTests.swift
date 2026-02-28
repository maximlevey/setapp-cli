@testable import SetappCLI
import XCTest

final class CheckCommandTests: CommandTestCase {
    // MARK: - Tests

    func testRunsWithoutError() throws {
        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 42)
        ]

        var cmd = try CheckCommand.parse([])

        // The command scans /Applications and ~/Applications directories.
        // In a test environment these may be empty or missing, which is fine
        // since the command gracefully skips missing directories.
        XCTAssertNoThrow(try cmd.run())
    }

    func testWithInstallFlag() throws {
        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 42)
        ]

        var cmd = try CheckCommand.parse(["--install"])

        // In a test environment with no matching apps in /Applications,
        // the command should find nothing and return without error.
        XCTAssertNoThrow(try cmd.run())
        XCTAssertTrue(mockInstaller.installedIDs.isEmpty, "No apps should be installed when none are found")
    }

    func testDatabaseError() throws {
        mockLookup.error = SetappError.databaseNotFound(path: "/fake/path")

        var cmd = try CheckCommand.parse([])

        XCTAssertThrowsError(try cmd.run()) { error in
            guard let setappError = error as? SetappError else {
                return XCTFail("Expected SetappError, got \(type(of: error))")
            }
            if case .databaseNotFound = setappError {
                // Expected
            } else {
                XCTFail("Expected databaseNotFound, got \(setappError)")
            }
        }
    }
}
