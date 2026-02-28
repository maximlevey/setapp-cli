@testable import SetappCLI
import XCTest

final class ReinstallCommandTests: CommandTestCase {
    // MARK: - Tests

    func testAppNotFound() throws {
        var cmd = try ReinstallCommand.parse(["NonExistent"])

        XCTAssertThrowsError(try cmd.run()) { error in
            guard let setappError = error as? SetappError else {
                return XCTFail("Expected SetappError, got \(type(of: error))")
            }
            if case let .appNotFound(name) = setappError {
                XCTAssertEqual(name, "NonExistent")
            } else {
                XCTFail("Expected appNotFound, got \(setappError)")
            }
        }
    }

    func testNotInstalledSkipsUninstall() throws {
        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 42)
        ]

        var cmd = try ReinstallCommand.parse(["Proxyman"])
        try cmd.run()

        XCTAssertTrue(mockInstaller.uninstalledIDs.isEmpty, "Should not uninstall when app is not currently installed")
        XCTAssertEqual(mockInstaller.installedIDs, [42], "Should still install the app")
    }

    func testAlreadyInstalledUninstallsThenInstalls() throws {
        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 42)
        ]
        mockDetector.installedNames = ["Proxyman"]

        var cmd = try ReinstallCommand.parse(["Proxyman"])
        try cmd.run()

        XCTAssertEqual(mockInstaller.uninstalledIDs, [42], "Should uninstall the app first")
        XCTAssertEqual(mockInstaller.installedIDs, [42], "Should then install the app")
    }

    func testCorrectOrder() throws {
        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 42)
        ]
        mockDetector.installedNames = ["Proxyman"]

        var cmd = try ReinstallCommand.parse(["Proxyman"])
        try cmd.run()

        // Uninstall happens first, then install.
        // Both arrays should have exactly one element with the same ID.
        XCTAssertEqual(mockInstaller.uninstalledIDs.count, 1)
        XCTAssertEqual(mockInstaller.installedIDs.count, 1)
        XCTAssertEqual(mockInstaller.uninstalledIDs.first, 42)
        XCTAssertEqual(mockInstaller.installedIDs.first, 42)
    }
}
