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
