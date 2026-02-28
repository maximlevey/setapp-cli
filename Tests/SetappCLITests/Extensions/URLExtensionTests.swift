@testable import SetappCLI
import XCTest

final class URLExtensionTests: XCTestCase {
    func testSetappDirectoryIsUnderHome() {
        let dir = URL.setappDirectory
        let home = FileManager.default.homeDirectoryForCurrentUser
        XCTAssertTrue(dir.path.hasPrefix(home.path))
    }

    func testSetappDirectoryPath() {
        let dir = URL.setappDirectory
        XCTAssertTrue(dir.path.hasSuffix(".setapp"))
    }

    func testDefaultAppListPath() {
        let path = URL.defaultAppListPath
        XCTAssertTrue(path.path.hasSuffix(".setapp/AppList"))
    }

    func testSetappAppsDirectoriesCount() {
        let dirs = URL.setappAppsDirectories
        XCTAssertEqual(dirs.count, 2)
    }

    func testSetappAppsDirectoriesContainSetapp() {
        let dirs = URL.setappAppsDirectories
        XCTAssertTrue(dirs.allSatisfy { $0.lastPathComponent == "Setapp" })
    }

    func testSetappDatabasePath() {
        let database = URL.setappDatabase
        XCTAssertTrue(database.path.contains("Apps.sqlite"))
    }

    func testSetappFrameworksPath() {
        let frameworks = URL.setappFrameworks
        XCTAssertTrue(frameworks.path.contains("Frameworks"))
    }
}
