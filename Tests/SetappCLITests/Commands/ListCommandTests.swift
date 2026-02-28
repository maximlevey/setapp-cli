@testable import SetappCLI
import XCTest

final class ListCommandTests: CommandTestCase {
    // MARK: - Tests

    func testListsOnlyInstalledApps() throws {
        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 1),
            SetappApp(name: "CleanMyMac", bundleIdentifier: "com.cleanmymac", identifier: 2),
            SetappApp(name: "Bartender", bundleIdentifier: "com.bartender", identifier: 3)
        ]
        mockDetector.installedNames = ["Proxyman", "Bartender"]

        var cmd = try ListCommand.parse([])

        // Should not throw; it prints the installed apps to stdout.
        XCTAssertNoThrow(try cmd.run())
    }

    func testNoInstalledApps() throws {
        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 1),
            SetappApp(name: "CleanMyMac", bundleIdentifier: "com.cleanmymac", identifier: 2)
        ]

        var cmd = try ListCommand.parse([])

        // No apps installed, should run without error.
        XCTAssertNoThrow(try cmd.run())
    }

    func testDatabaseError() throws {
        mockLookup.error = SetappError.databaseNotFound(path: "/fake/path")

        var cmd = try ListCommand.parse([])

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
