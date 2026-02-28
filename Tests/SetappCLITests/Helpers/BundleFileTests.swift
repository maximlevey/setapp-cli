import Foundation
@testable import SetappCLI
import XCTest

final class BundleFileTests: XCTestCase {
    // MARK: - resolvePath

    func testResolvePathFlagValueTakesPriority() {
        let result = BundleFile.resolvePath(flagValue: "/custom/path")
        XCTAssertEqual(result.path, "/custom/path")
    }

    func testResolvePathDefaultPathWhenNoFlag() {
        let result = BundleFile.resolvePath(flagValue: nil)
        XCTAssertEqual(result, URL.defaultBundlePath)
    }

    func testResolvePathEmptyStringFallsToDefault() {
        let result = BundleFile.resolvePath(flagValue: "")
        XCTAssertEqual(result, URL.defaultBundlePath)
    }

    func testResolvePathExpandsTilde() {
        let result = BundleFile.resolvePath(flagValue: "~/my/bundle")
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
        let file = tmp.createFile(named: "bundle", content: content)

        let names = try BundleFile.parse(at: file)
        XCTAssertEqual(names, ["Proxyman", "CleanMyMac", "Bartender"])
    }

    func testParseStripsInlineComments() throws {
        let tmp = TempDirectory()
        let content = "Proxyman # my favorite\nBartender # useful tool\n"
        let file = tmp.createFile(named: "bundle", content: content)

        let names = try BundleFile.parse(at: file)
        XCTAssertEqual(names, ["Proxyman", "Bartender"])
    }

    func testParseStripsFullLineComments() throws {
        let tmp = TempDirectory()
        let content = "# This is a comment\n# Another comment\nProxyman\n"
        let file = tmp.createFile(named: "bundle", content: content)

        let names = try BundleFile.parse(at: file)
        XCTAssertEqual(names, ["Proxyman"])
    }

    func testParseStripsBlankLines() throws {
        let tmp = TempDirectory()
        let content = "Proxyman\n\n\nBartender\n\n"
        let file = tmp.createFile(named: "bundle", content: content)

        let names = try BundleFile.parse(at: file)
        XCTAssertEqual(names, ["Proxyman", "Bartender"])
    }

    func testParseTrimsWhitespaceFromNames() throws {
        let tmp = TempDirectory()
        let content = "  Proxyman  \n\tBartender\t\n"
        let file = tmp.createFile(named: "bundle", content: content)

        let names = try BundleFile.parse(at: file)
        XCTAssertEqual(names, ["Proxyman", "Bartender"])
    }

    func testParseThrowsBundleFileNotFoundForMissingFile() {
        let missingURL = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)/bundle")

        XCTAssertThrowsError(try BundleFile.parse(at: missingURL)) { error in
            guard let setappError = error as? SetappError else {
                XCTFail("Expected SetappError, got \(type(of: error))")
                return
            }
            guard case .bundleFileNotFound = setappError else {
                XCTFail("Expected bundleFileNotFound, got \(setappError)")
                return
            }
        }
    }

    func testParseReturnsEmptyArrayForOnlyCommentsAndBlanks() throws {
        let tmp = TempDirectory()
        let content = "# comment one\n# comment two\n\n  \n"
        let file = tmp.createFile(named: "bundle", content: content)

        let names = try BundleFile.parse(at: file)
        XCTAssertTrue(names.isEmpty)
    }

    // MARK: - write

    func testWriteCreatesParentDirectories() throws {
        let tmp = TempDirectory()
        let nested = tmp.url
            .appendingPathComponent("deep")
            .appendingPathComponent("nested")
            .appendingPathComponent("bundle")

        try BundleFile.write(names: ["Proxyman"], to: nested)

        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.path))
    }

    func testWriteDoesNotIncludeHeader() throws {
        let tmp = TempDirectory()
        let file = tmp.url.appendingPathComponent("bundle")

        try BundleFile.write(names: ["Proxyman"], to: file)

        let content = try String(contentsOf: file, encoding: .utf8)
        XCTAssertFalse(content.hasPrefix("#"), "Written file must not start with a comment header")
        XCTAssertTrue(content.contains("Proxyman"), "Written file must contain app names")
    }

    func testWriteSortsNamesCaseInsensitively() throws {
        let tmp = TempDirectory()
        let file = tmp.url.appendingPathComponent("bundle")

        try BundleFile.write(names: ["Proxyman", "bartender", "CleanMyMac"], to: file)

        let content = try String(contentsOf: file, encoding: .utf8)
        let lines = content.components(separatedBy: "\n")
        let appLines = lines.filter { !$0.hasPrefix("#") && !$0.isEmpty }
        XCTAssertEqual(appLines, ["bartender", "CleanMyMac", "Proxyman"])
    }

    func testWriteOutputEndsWithNewline() throws {
        let tmp = TempDirectory()
        let file = tmp.url.appendingPathComponent("bundle")

        try BundleFile.write(names: ["Proxyman"], to: file)

        let content = try String(contentsOf: file, encoding: .utf8)
        XCTAssertTrue(content.hasSuffix("\n"))
    }

    func testWriteThenParseRoundTrip() throws {
        let tmp = TempDirectory()
        let file = tmp.url.appendingPathComponent("bundle")

        let original = ["Proxyman", "bartender", "CleanMyMac"]
        try BundleFile.write(names: original, to: file)

        let parsed = try BundleFile.parse(at: file)
        let expectedSorted = ["bartender", "CleanMyMac", "Proxyman"]
        XCTAssertEqual(parsed, expectedSorted)
    }
}
