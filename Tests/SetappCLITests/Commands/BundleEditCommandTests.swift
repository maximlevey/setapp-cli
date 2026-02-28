import Foundation
@testable import SetappCLI
import XCTest

final class BundleEditCommandTests: CommandTestCase {
    // MARK: - File creation

    func testCreatesEmptyFileWhenMissing() throws {
        let tmp = TempDirectory()
        let filePath = tmp.url.appendingPathComponent("new-bundle").path

        XCTAssertFalse(FileManager.default.fileExists(atPath: filePath))

        // Set EDITOR to "true" (a no-op command) so the process exits immediately.
        setenv("EDITOR", "true", 1)
        defer { unsetenv("EDITOR") }

        var cmd = try BundleEditCommand.parse(["--file", filePath])
        try cmd.run()

        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath),
                      "File should be created")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        XCTAssertEqual(content, "", "Newly created AppList file should be empty")
    }

    func testDoesNotOverwriteExistingFile() throws {
        let tmp = TempDirectory()
        let bundlePath = tmp.createFile(named: "bundle", content: "Proxyman\nBartender\n")

        setenv("EDITOR", "true", 1)
        defer { unsetenv("EDITOR") }

        var cmd = try BundleEditCommand.parse(["--file", bundlePath.path])
        try cmd.run()

        let content = try String(contentsOfFile: bundlePath.path, encoding: .utf8)
        XCTAssertTrue(content.contains("Proxyman"), "Existing content should be preserved")
        XCTAssertTrue(content.contains("Bartender"), "Existing content should be preserved")
    }

    func testCreatesParentDirectories() throws {
        let tmp = TempDirectory()
        let nested = tmp.url.appendingPathComponent("a/b/c/bundle").path

        setenv("EDITOR", "true", 1)
        defer { unsetenv("EDITOR") }

        var cmd = try BundleEditCommand.parse(["--file", nested])
        try cmd.run()

        XCTAssertTrue(FileManager.default.fileExists(atPath: nested), "File should be created in nested directory")
    }

    // MARK: - Argument parsing

    func testFileOptionParsing() throws {
        let cmd = try BundleEditCommand.parse(["--file", "/tmp/custom-bundle"])
        XCTAssertEqual(cmd.file, "/tmp/custom-bundle")
    }

    func testShortFileOptionParsing() throws {
        let cmd = try BundleEditCommand.parse(["-f", "/tmp/custom-bundle"])
        XCTAssertEqual(cmd.file, "/tmp/custom-bundle")
    }

    func testDefaultFileIsNil() throws {
        let cmd = try BundleEditCommand.parse([])
        XCTAssertNil(cmd.file)
    }
}
