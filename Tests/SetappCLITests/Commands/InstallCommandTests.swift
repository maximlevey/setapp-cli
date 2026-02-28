@testable import SetappCLI
import XCTest

final class InstallCommandTests: CommandTestCase {
    // MARK: - Tests

    func testAlreadyInstalled() throws {
        mockDetector.installedNames = ["Proxyman"]
        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 42)
        ]

        var cmd = try InstallCommand.parse(["Proxyman"])
        try cmd.run()

        XCTAssertTrue(mockInstaller.installedIDs.isEmpty, "Should not call installer when app is already installed")
    }

    func testAppNotFoundInDatabase() throws {
        var cmd = try InstallCommand.parse(["NonExistent"])

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

    func testSuccessfulInstall() throws {
        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 42)
        ]

        var cmd = try InstallCommand.parse(["Proxyman"])
        try cmd.run()

        XCTAssertEqual(mockInstaller.installedIDs, [42])
    }

    func testReplaceFindsNonSetappApp() throws {
        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 42)
        ]
        mockDetector.nonSetappPaths = [
            "Proxyman": URL(fileURLWithPath: "/Applications/Proxyman.app")
        ]

        var cmd = try InstallCommand.parse(["Proxyman", "--replace"])
        try cmd.run()

        XCTAssertEqual(mockInstaller.installedIDs, [42], "Install should still be called with replace flag")
    }

    func testWithoutReplaceDoesntLookForNonSetappApp() throws {
        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 42)
        ]
        mockDetector.nonSetappPaths = [
            "Proxyman": URL(fileURLWithPath: "/Applications/Proxyman.app")
        ]

        var cmd = try InstallCommand.parse(["Proxyman"])
        try cmd.run()

        XCTAssertEqual(mockInstaller.installedIDs, [42])
    }

    func testInstallerError() throws {
        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 42)
        ]
        mockInstaller.installError = SetappError.installFailed(app: "Proxyman", message: "XPC failed")

        var cmd = try InstallCommand.parse(["Proxyman"])

        XCTAssertThrowsError(try cmd.run()) { error in
            guard let setappError = error as? SetappError else {
                return XCTFail("Expected SetappError, got \(type(of: error))")
            }
            if case let .installFailed(app, _) = setappError {
                XCTAssertEqual(app, "Proxyman")
            } else {
                XCTFail("Expected installFailed, got \(setappError)")
            }
        }
    }
}
