@testable import SetappCLI
import XCTest

final class BundleDumpCommandTests: CommandTestCase {
    // MARK: - Tests

    func testNoAppsInstalledWarning() throws {
        try XCTSkipUnless(setappDirectoryExists, "Setapp directory not present on this machine")

        var cmd = try BundleDumpCommand.parse([])
        // mockDetector.allInstalledNames defaults to [], so no apps.
        XCTAssertNoThrow(try cmd.run())
    }

    func testWritesBundleFileWhenAppsInstalled() throws {
        try XCTSkipUnless(setappDirectoryExists, "Setapp directory not present on this machine")

        let tmp = TempDirectory()
        let filePath = tmp.url.appendingPathComponent("test-bundle").path

        mockDetector.allInstalledNames = ["Proxyman", "Bartender"]

        var cmd = try BundleDumpCommand.parse(["--file", filePath])
        try cmd.run()

        let written = FileManager.default.fileExists(atPath: filePath)
        XCTAssertTrue(written, "Bundle file should have been written")

        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        XCTAssertFalse(content.hasPrefix("#"), "Written file must not start with a comment header")
        XCTAssertTrue(content.contains("Proxyman"), "Written file must contain app names")
    }

    func testListFlagPrintsApps() throws {
        try XCTSkipUnless(setappDirectoryExists, "Setapp directory not present on this machine")

        mockDetector.allInstalledNames = ["Proxyman", "Bartender"]

        var cmd = try BundleDumpCommand.parse(["--list"])
        XCTAssertNoThrow(try cmd.run())
    }

    func testListFlagDoesNotWriteFile() throws {
        try XCTSkipUnless(setappDirectoryExists, "Setapp directory not present on this machine")

        let tmp = TempDirectory()
        let filePath = tmp.url.appendingPathComponent("should-not-exist").path

        mockDetector.allInstalledNames = ["Proxyman"]

        var cmd = try BundleDumpCommand.parse(["--list", "--file", filePath])
        try cmd.run()

        XCTAssertFalse(FileManager.default.fileExists(atPath: filePath),
                       "File should not be written when --list is passed")
    }

    func testThrowsWhenNoSetappDirectory() throws {
        try XCTSkipIf(setappDirectoryExists, "Setapp directory present -- cannot test missing dir path")

        var cmd = try BundleDumpCommand.parse([])

        XCTAssertThrowsError(try cmd.run()) { error in
            guard let setappError = error as? SetappError else {
                return XCTFail("Expected SetappError, got \(type(of: error))")
            }
            if case .setappAppsDirectoryNotFound = setappError {
                // Expected
            } else {
                XCTFail("Expected setappAppsDirectoryNotFound, got \(setappError)")
            }
        }
    }
}
