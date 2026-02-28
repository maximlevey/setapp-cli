@testable import SetappCLI
import XCTest

final class BundleCleanupCommandTests: CommandTestCase {
    // MARK: - Tests

    func testNothingToCleanUp() throws {
        let tmp = TempDirectory()
        let bundlePath = tmp.createFile(named: "bundle", content: "Proxyman\nBartender\n")

        mockDetector.allInstalledNames = ["Proxyman", "Bartender"]

        var cmd = try BundleCleanupCommand.parse(["--file", bundlePath.path])
        try cmd.run()

        XCTAssertTrue(mockInstaller.uninstalledIDs.isEmpty, "Nothing should be uninstalled when all apps are in the bundle")
    }

    func testRemovesExtraApps() throws {
        let tmp = TempDirectory()
        let bundlePath = tmp.createFile(named: "bundle", content: "Proxyman\n")

        mockDetector.allInstalledNames = ["Proxyman", "Bartender", "CleanMyMac"]
        mockLookup.apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 1),
            SetappApp(name: "Bartender", bundleIdentifier: "com.bartender", identifier: 2),
            SetappApp(name: "CleanMyMac", bundleIdentifier: "com.cleanmymac", identifier: 3)
        ]

        var cmd = try BundleCleanupCommand.parse(["--file", bundlePath.path])
        try cmd.run()

        XCTAssertEqual(mockInstaller.uninstalledIDs.sorted(), [2, 3], "Should uninstall Bartender and CleanMyMac")
    }

    func testContinuesOnFailure() throws {
        let tmp = TempDirectory()
        let bundlePath = tmp.createFile(named: "bundle", content: "Proxyman\n")

        mockDetector.allInstalledNames = ["Proxyman", "Bartender", "CleanMyMac"]
        mockLookup.apps = [
            SetappApp(name: "Bartender", bundleIdentifier: "com.bartender", identifier: 2),
            SetappApp(name: "CleanMyMac", bundleIdentifier: "com.cleanmymac", identifier: 3)
        ]

        // Create a custom mock that fails on one uninstall.
        let failingInstaller = FailOnUninstallInstaller(failOnID: 2)
        Dependencies.installer = failingInstaller

        var cmd = try BundleCleanupCommand.parse(["--file", bundlePath.path])

        // Should not throw -- errors are caught per-app.
        XCTAssertNoThrow(try cmd.run())
        XCTAssertEqual(failingInstaller.uninstalledIDs, [3], "Should uninstall CleanMyMac even though Bartender failed")
    }

    func testCaseInsensitiveMatch() throws {
        let tmp = TempDirectory()
        let bundlePath = tmp.createFile(named: "bundle", content: "proxyman\nbartender\n")

        mockDetector.allInstalledNames = ["Proxyman", "Bartender"]

        var cmd = try BundleCleanupCommand.parse(["--file", bundlePath.path])
        try cmd.run()

        XCTAssertTrue(mockInstaller.uninstalledIDs.isEmpty, "Case-insensitive match should prevent cleanup")
    }
}
