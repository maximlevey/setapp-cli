@testable import SetappCLI
import XCTest

final class BundleInstallCommandTests: CommandTestCase {
    // MARK: - Tests

    func testInstallsMissingApps() throws {
        let tmp = TempDirectory()
        let bundlePath = tmp.createFile(named: "bundle", content: "Proxyman\nBartender\n")

        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 1),
            SetappApp(name: "Bartender", bundleIdentifier: "com.bartender", identifier: 2)
        ]

        var cmd = try BundleInstallCommand.parse(["--file", bundlePath.path])
        try cmd.run()

        XCTAssertEqual(mockInstaller.installedIDs.sorted(), [1, 2])
    }

    func testSkipsAlreadyInstalled() throws {
        let tmp = TempDirectory()
        let bundlePath = tmp.createFile(named: "bundle", content: "Proxyman\nBartender\n")

        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 1),
            SetappApp(name: "Bartender", bundleIdentifier: "com.bartender", identifier: 2)
        ]
        mockDetector.installedNames = ["Proxyman"]

        var cmd = try BundleInstallCommand.parse(["--file", bundlePath.path])
        try cmd.run()

        XCTAssertEqual(mockInstaller.installedIDs, [2], "Should only install Bartender since Proxyman is already installed")
    }

    func testContinuesOnFailure() throws {
        let tmp = TempDirectory()
        let bundlePath = tmp.createFile(named: "bundle", content: "Proxyman\nBartender\n")

        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 1),
            SetappApp(name: "Bartender", bundleIdentifier: "com.bartender", identifier: 2)
        ]

        // Create a custom mock installer that fails on the first install
        // but succeeds on the second.
        let failingInstaller = FailOnInstallInstaller(failOnID: 1)
        Dependencies.installer = failingInstaller

        var cmd = try BundleInstallCommand.parse(["--file", bundlePath.path])

        // Should not throw -- errors are caught per-app.
        XCTAssertNoThrow(try cmd.run())

        XCTAssertEqual(failingInstaller.installedIDs, [2], "Should install Bartender even though Proxyman failed")
    }

    func testAppNotInCatalogue() throws {
        let tmp = TempDirectory()
        let bundlePath = tmp.createFile(named: "bundle", content: "Proxyman\nUnknownApp\n")

        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 1)
        ]

        var cmd = try BundleInstallCommand.parse(["--file", bundlePath.path])

        // Should not throw -- unknown apps are skipped with a printed error.
        XCTAssertNoThrow(try cmd.run())
        XCTAssertEqual(mockInstaller.installedIDs, [1], "Should install Proxyman but skip unknown app")
    }

    func testEmptyBundleFile() throws {
        let tmp = TempDirectory()
        let bundlePath = tmp.createFile(named: "bundle", content: "# just a comment\n\n")

        var cmd = try BundleInstallCommand.parse(["--file", bundlePath.path])

        // Empty bundle (only comments) should print a warning, no installs.
        XCTAssertNoThrow(try cmd.run())
        XCTAssertTrue(mockInstaller.installedIDs.isEmpty)
    }
}
