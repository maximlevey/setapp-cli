import Foundation
@testable import SetappCLI
import XCTest

final class SetappDetectorTests: XCTestCase {
    // MARK: - isInstalled

    func testIsInstalledReturnsTrueWhenAppExists() {
        let tmp = TempDirectory()
        _ = tmp.createFakeApp(named: "Proxyman", bundleID: "com.proxyman")

        let result = SetappDetector.isInstalled("Proxyman", appsDirs: [tmp.url])
        XCTAssertTrue(result)
    }

    func testIsInstalledCaseInsensitiveMatch() {
        let tmp = TempDirectory()
        _ = tmp.createFakeApp(named: "Proxyman", bundleID: "com.proxyman")

        let result = SetappDetector.isInstalled("proxyman", appsDirs: [tmp.url])
        XCTAssertTrue(result)
    }

    func testIsInstalledReturnsFalseWhenNotPresent() {
        let tmp = TempDirectory()
        _ = tmp.createFakeApp(named: "Bartender", bundleID: "com.bartender")

        let result = SetappDetector.isInstalled("Proxyman", appsDirs: [tmp.url])
        XCTAssertFalse(result)
    }

    func testIsInstalledHandlesNonExistentDirectory() {
        let fakeDir = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)")

        let result = SetappDetector.isInstalled("Proxyman", appsDirs: [fakeDir])
        XCTAssertFalse(result)
    }

    func testIsInstalledSearchesMultipleDirectories() {
        let dir1 = TempDirectory()
        let dir2 = TempDirectory()
        _ = dir2.createFakeApp(named: "Proxyman", bundleID: "com.proxyman")

        let result = SetappDetector.isInstalled("Proxyman", appsDirs: [dir1.url, dir2.url])
        XCTAssertTrue(result)
    }

    // MARK: - readBundleID

    func testReadBundleIDFromValidPlist() {
        let tmp = TempDirectory()
        let appURL = tmp.createFakeApp(named: "Proxyman", bundleID: "com.proxyman.NSProxy")

        let bundleID = SetappDetector.readBundleID(at: appURL)
        XCTAssertEqual(bundleID, "com.proxyman.NSProxy")
    }

    func testReadBundleIDReturnsNilForAppWithoutInfoPlist() {
        let tmp = TempDirectory()
        // Create .app/Contents directory without an Info.plist
        let contentsDir = tmp.url
            .appendingPathComponent("NoPlist.app")
            .appendingPathComponent("Contents")
        try? FileManager.default.createDirectory(
            at: contentsDir,
            withIntermediateDirectories: true
        )

        let appURL = tmp.url.appendingPathComponent("NoPlist.app")
        let bundleID = SetappDetector.readBundleID(at: appURL)
        XCTAssertNil(bundleID)
    }

    func testReadBundleIDReturnsNilForNonExistentAppPath() {
        let fakeApp = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).app")

        let bundleID = SetappDetector.readBundleID(at: fakeApp)
        XCTAssertNil(bundleID)
    }

    // MARK: - installedAppNames

    func testInstalledAppNamesReturnsSortedList() {
        let tmp = TempDirectory()
        _ = tmp.createFakeApp(named: "Proxyman", bundleID: "com.proxyman")
        _ = tmp.createFakeApp(named: "Bartender", bundleID: "com.bartender")
        _ = tmp.createFakeApp(named: "CleanMyMac", bundleID: "com.cleanmymac")

        let names = SetappDetector.installedAppNames(appsDirs: [tmp.url])
        XCTAssertEqual(names, ["Bartender", "CleanMyMac", "Proxyman"])
    }

    func testInstalledAppNamesReturnsEmptyForEmptyDirectory() {
        let tmp = TempDirectory()

        let names = SetappDetector.installedAppNames(appsDirs: [tmp.url])
        XCTAssertTrue(names.isEmpty)
    }

    func testInstalledAppNamesFiltersOutNonAppEntries() {
        let tmp = TempDirectory()
        _ = tmp.createFakeApp(named: "Proxyman", bundleID: "com.proxyman")
        _ = tmp.createFile(named: "readme.txt", content: "not an app")

        let names = SetappDetector.installedAppNames(appsDirs: [tmp.url])
        XCTAssertEqual(names, ["Proxyman"])
    }

    func testInstalledAppNamesHandlesNonExistentDirectories() {
        let fakeDir = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)")

        let names = SetappDetector.installedAppNames(appsDirs: [fakeDir])
        XCTAssertTrue(names.isEmpty)
    }

    // MARK: - findNonSetappApp

    func testFindNonSetappAppReturnsNilForUnknownApp() {
        // Use a UUID-based name that definitely does not exist in /Applications
        let result = SetappDetector.findNonSetappApp(named: "NonExistentApp_\(UUID().uuidString)")
        XCTAssertNil(result)
    }
}
