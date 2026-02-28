import ArgumentParser
@testable import SetappCLI
import XCTest

final class BundleCheckCommandTests: CommandTestCase {
    // MARK: - --path flag: all installed

    func testAllInstalledWithCustomPath() throws {
        let tmp = TempDirectory()

        let appsDir = tmp.url.appendingPathComponent("Apps")
        try FileManager.default.createDirectory(
            at: appsDir.appendingPathComponent("Proxyman.app"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: appsDir.appendingPathComponent("Bartender.app"),
            withIntermediateDirectories: true
        )

        let listPath = tmp.createFile(named: "AppList", content: "Proxyman\nBartender\n")
        var cmd = try BundleCheckCommand.parse([
            "--file", listPath.path,
            "--path", appsDir.path
        ])

        XCTAssertNoThrow(try cmd.run())
    }

    // MARK: - --path flag: missing apps

    func testMissingAppsWithCustomPath() throws {
        let tmp = TempDirectory()

        let appsDir = tmp.url.appendingPathComponent("Apps")
        try FileManager.default.createDirectory(
            at: appsDir.appendingPathComponent("Proxyman.app"),
            withIntermediateDirectories: true
        )

        let listPath = tmp.createFile(named: "AppList", content: "Proxyman\nBartender\n")
        var cmd = try BundleCheckCommand.parse([
            "--file", listPath.path,
            "--path", appsDir.path
        ])

        XCTAssertThrowsError(try cmd.run()) { error in
            guard let exitError = error as? ExitCode else {
                return XCTFail("Expected ExitCode, got \(type(of: error))")
            }
            XCTAssertEqual(exitError.rawValue, 1)
        }
    }

    // MARK: - Default paths (no --path)

    func testDefaultPathsUsedWhenNoPathFlag() throws {
        let tmp = TempDirectory()
        let listPath = tmp.createFile(named: "AppList",
                                      content: "ThisAppDefinitelyDoesNotExist999\n")
        var cmd = try BundleCheckCommand.parse(["--file", listPath.path])

        XCTAssertThrowsError(try cmd.run()) { error in
            guard let exitError = error as? ExitCode else {
                return XCTFail("Expected ExitCode, got \(type(of: error))")
            }
            XCTAssertEqual(exitError.rawValue, 1)
        }
    }

    // MARK: - AppList file not found

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
