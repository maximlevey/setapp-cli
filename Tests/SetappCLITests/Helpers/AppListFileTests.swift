import Foundation
@testable import SetappCLI
import XCTest

final class AppListFileTests: XCTestCase {
    // MARK: - resolvePath

    func testResolvePathFlagValueTakesPriority() {
        let result = AppListFile.resolvePath(flagValue: "/custom/path")
        XCTAssertEqual(result.path, "/custom/path")
    }

    func testResolvePathDefaultPathWhenNoFlag() {
        let result = AppListFile.resolvePath(flagValue: nil)
        XCTAssertEqual(result, URL.defaultAppListPath)
    }

    func testResolvePathEmptyStringFallsToDefault() {
        let result = AppListFile.resolvePath(flagValue: "")
        XCTAssertEqual(result, URL.defaultAppListPath)
    }

    func testResolvePathExpandsTilde() {
        let result = AppListFile.resolvePath(flagValue: "~/my/bundle")
        let expected = (("~/my/bundle" as NSString).expandingTildeInPath)
        XCTAssertEqual(result.path, expected)
        XCTAssertFalse(result.path.contains("~"))
    }

    // MARK: - parse

    func testParseReadsAppNamesFromWellFormedFile() throws {
        let tmp = TempDirectory()
        let content = """
        # header comment
        Proxyman
        CleanMyMac
        Bartender
        """
        let file = tmp.createFile(named: "AppList", content: content)

        let names = try AppListFile.parse(at: file)
        XCTAssertEqual(names, ["Proxyman", "CleanMyMac", "Bartender"])
    }

    func testParseStripsInlineComments() throws {
        let tmp = TempDirectory()
        let content = "Proxyman # my favorite\nBartender # useful tool\n"
        let file = tmp.createFile(named: "AppList", content: content)

        let names = try AppListFile.parse(at: file)
        XCTAssertEqual(names, ["Proxyman", "Bartender"])
    }

    func testParseStripsFullLineComments() throws {
        let tmp = TempDirectory()
        let content = "# This is a comment\n# Another comment\nProxyman\n"
        let file = tmp.createFile(named: "AppList", content: content)

        let names = try AppListFile.parse(at: file)
        XCTAssertEqual(names, ["Proxyman"])
    }

    func testParseStripsBlankLines() throws {
        let tmp = TempDirectory()
        let content = "Proxyman\n\n\nBartender\n\n"
        let file = tmp.createFile(named: "AppList", content: content)

        let names = try AppListFile.parse(at: file)
        XCTAssertEqual(names, ["Proxyman", "Bartender"])
    }

    func testParseTrimsWhitespaceFromNames() throws {
        let tmp = TempDirectory()
        let content = "  Proxyman  \n\tBartender\t\n"
        let file = tmp.createFile(named: "AppList", content: content)

        let names = try AppListFile.parse(at: file)
        XCTAssertEqual(names, ["Proxyman", "Bartender"])
    }

    func testParseThrowsAppListFileNotFoundForMissingFile() {
        let missingURL = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)/AppList")

        XCTAssertThrowsError(try AppListFile.parse(at: missingURL)) { error in
            guard let setappError = error as? SetappError else {
                XCTFail("Expected SetappError, got \(type(of: error))")
                return
            }
            guard case .appListFileNotFound = setappError else {
                XCTFail("Expected appListFileNotFound, got \(setappError)")
                return
            }
        }
    }

    func testParseReturnsEmptyArrayForOnlyCommentsAndBlanks() throws {
        let tmp = TempDirectory()
        let content = "# comment one\n# comment two\n\n  \n"
        let file = tmp.createFile(named: "AppList", content: content)

        let names = try AppListFile.parse(at: file)
        XCTAssertTrue(names.isEmpty)
    }

    // MARK: - write

    func testWriteCreatesParentDirectories() throws {
        let tmp = TempDirectory()
        let nested = tmp.url
            .appendingPathComponent("deep")
            .appendingPathComponent("nested")
            .appendingPathComponent("AppList")

        try AppListFile.write(names: ["Proxyman"], to: nested)

        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.path))
    }

    func testWriteDoesNotIncludeHeader() throws {
        let tmp = TempDirectory()
        let file = tmp.url.appendingPathComponent("AppList")

        try AppListFile.write(names: ["Proxyman"], to: file)

        let content = try String(contentsOf: file, encoding: .utf8)
        XCTAssertFalse(content.hasPrefix("#"), "Written file must not start with a comment header")
        XCTAssertTrue(content.contains("Proxyman"), "Written file must contain app names")
    }

    func testWriteSortsNamesCaseInsensitively() throws {
        let tmp = TempDirectory()
        let file = tmp.url.appendingPathComponent("AppList")

        try AppListFile.write(names: ["Proxyman", "bartender", "CleanMyMac"], to: file)

        let content = try String(contentsOf: file, encoding: .utf8)
        let lines = content.components(separatedBy: "\n")
        let appLines = lines.filter { !$0.hasPrefix("#") && !$0.isEmpty }
        XCTAssertEqual(appLines, ["bartender", "CleanMyMac", "Proxyman"])
    }

    func testWriteOutputEndsWithNewline() throws {
        let tmp = TempDirectory()
        let file = tmp.url.appendingPathComponent("AppList")

        try AppListFile.write(names: ["Proxyman"], to: file)

        let content = try String(contentsOf: file, encoding: .utf8)
        XCTAssertTrue(content.hasSuffix("\n"))
    }

    func testWriteThenParseRoundTrip() throws {
        let tmp = TempDirectory()
        let file = tmp.url.appendingPathComponent("AppList")

        let original = ["Proxyman", "bartender", "CleanMyMac"]
        try AppListFile.write(names: original, to: file)

        let parsed = try AppListFile.parse(at: file)
        let expectedSorted = ["bartender", "CleanMyMac", "Proxyman"]
        XCTAssertEqual(parsed, expectedSorted)
    }
}
