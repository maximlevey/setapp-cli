@testable import SetappCLI
import XCTest

final class RemoveCommandTests: CommandTestCase {
    // MARK: - Tests

    func testAppNotFound() throws {
        var cmd = try RemoveCommand.parse(["NonExistent"])

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

    func testAppNotInstalled() throws {
        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 42)
        ]

        var cmd = try RemoveCommand.parse(["Proxyman"])

        XCTAssertThrowsError(try cmd.run()) { error in
            guard let setappError = error as? SetappError else {
                return XCTFail("Expected SetappError, got \(type(of: error))")
            }
            if case let .appNotInstalled(name) = setappError {
                XCTAssertEqual(name, "Proxyman")
            } else {
                XCTFail("Expected appNotInstalled, got \(setappError)")
            }
        }
    }

    func testSuccessfulRemove() throws {
        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 42)
        ]
        mockDetector.installedNames = ["Proxyman"]

        var cmd = try RemoveCommand.parse(["Proxyman"])
        try cmd.run()

        XCTAssertEqual(mockInstaller.uninstalledIDs, [42])
    }

    func testUninstallerError() throws {
        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 42)
        ]
        mockDetector.installedNames = ["Proxyman"]
        mockInstaller.uninstallError = SetappError.uninstallFailed(app: "Proxyman", message: "XPC failed")

        var cmd = try RemoveCommand.parse(["Proxyman"])

        XCTAssertThrowsError(try cmd.run()) { error in
            guard let setappError = error as? SetappError else {
                return XCTFail("Expected SetappError, got \(type(of: error))")
            }
            if case let .uninstallFailed(app, _) = setappError {
                XCTAssertEqual(app, "Proxyman")
            } else {
                XCTFail("Expected uninstallFailed, got \(setappError)")
            }
        }
    }
}
