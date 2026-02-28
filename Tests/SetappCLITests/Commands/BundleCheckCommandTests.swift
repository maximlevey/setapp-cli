import ArgumentParser
@testable import SetappCLI
import XCTest

final class BundleCheckCommandTests: CommandTestCase {
    // MARK: - Tests

    func testAllInstalled() throws {
        let tmp = TempDirectory()
        let bundlePath = tmp.createFile(named: "bundle", content: "Proxyman\nBartender\n")

        mockDetector.installedNames = ["Proxyman", "Bartender"]

        var cmd = try BundleCheckCommand.parse(["--file", bundlePath.path])

        XCTAssertNoThrow(try cmd.run())
    }

    func testMissingApps() throws {
        let tmp = TempDirectory()
        let bundlePath = tmp.createFile(named: "bundle", content: "Proxyman\nBartender\n")

        mockDetector.installedNames = ["Proxyman"]

        var cmd = try BundleCheckCommand.parse(["--file", bundlePath.path])

        XCTAssertThrowsError(try cmd.run()) { error in
            // BundleCheckCommand throws ExitCode(1) when apps are missing.
            guard let exitError = error as? ExitCode else {
                return XCTFail("Expected ExitCode, got \(type(of: error))")
            }
            XCTAssertEqual(exitError.rawValue, 1)
        }
    }

    func testAppListFileNotFound() throws {
        var cmd = try BundleCheckCommand.parse(["--file", "/nonexistent/path/AppList"])

        XCTAssertThrowsError(try cmd.run()) { error in
            guard let setappError = error as? SetappError else {
                return XCTFail("Expected SetappError, got \(type(of: error))")
            }
            if case .appListFileNotFound = setappError {
                // Expected
            } else {
                XCTFail("Expected appListFileNotFound, got \(setappError)")
            }
        }
    }
}
