import Foundation
@testable import SetappCLI
import SQLite3
import XCTest

final class DatabaseTests: XCTestCase {
    private var tempDatabasePaths: [String] = []

    override func tearDown() {
        super.tearDown()
        for path in tempDatabasePaths {
            try? FileManager.default.removeItem(atPath: path)
        }
        tempDatabasePaths.removeAll()
    }

    /// Create a temporary SQLite database with the Setapp schema and return its path.
    private func createTestDatabase(
        apps: [(name: String, bundleID: String?, identifier: Int)]
    ) -> String {
        let path = NSTemporaryDirectory() + UUID().uuidString + ".sqlite"
        tempDatabasePaths.append(path)

        var database: OpaquePointer?
        sqlite3_open(path, &database)
        sqlite3_exec(
            database,
            "CREATE TABLE ZAPP (ZNAME TEXT, ZBUNDLEIDENTIFIER TEXT, ZIDENTIFIER INTEGER)",
            nil, nil, nil
        )

        for app in apps {
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(
                database,
                "INSERT INTO ZAPP (ZNAME, ZBUNDLEIDENTIFIER, ZIDENTIFIER) VALUES (?, ?, ?)",
                -1, &stmt, nil
            )
            sqlite3_bind_text(stmt, 1, (app.name as NSString).utf8String, -1, nil)
            if let bid = app.bundleID {
                sqlite3_bind_text(stmt, 2, (bid as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 2)
            }
            sqlite3_bind_int64(stmt, 3, Int64(app.identifier))
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
        sqlite3_close(database)
        return path
    }

    // MARK: - connect

    func testConnectThrowsDatabaseNotFoundForNonExistentPath() {
        let fakePath = "/nonexistent/\(UUID().uuidString).sqlite"

        XCTAssertThrowsError(try Database.connect(databasePath: fakePath)) { error in
            guard let setappError = error as? SetappError else {
                XCTFail("Expected SetappError, got \(type(of: error))")
                return
            }
            guard case .databaseNotFound = setappError else {
                XCTFail("Expected databaseNotFound, got \(setappError)")
                return
            }
        }
    }

    func testConnectSuccessfullyOpensValidDatabase() throws {
        let path = createTestDatabase(apps: [])

        let conn = try Database.connect(databasePath: path)
        XCTAssertNotNil(conn)
        sqlite3_close(conn)
    }

    // MARK: - getAppByName

    func testGetAppByNameReturnsMatchingAppExactCase() throws {
        let path = createTestDatabase(apps: [
            (name: "Proxyman", bundleID: "com.proxyman.NSProxy", identifier: 100)
        ])

        let conn = try Database.connect(databasePath: path)
        defer { sqlite3_close(conn) }

        let app = try Database.getAppByName("Proxyman", connection: conn)
        XCTAssertNotNil(app)
        XCTAssertEqual(app?.name, "Proxyman")
        XCTAssertEqual(app?.bundleIdentifier, "com.proxyman.NSProxy")
        XCTAssertEqual(app?.identifier, 100)
    }

    func testGetAppByNameCaseInsensitiveMatch() throws {
        let path = createTestDatabase(apps: [
            (name: "Proxyman", bundleID: "com.proxyman.NSProxy", identifier: 100)
        ])

        let conn = try Database.connect(databasePath: path)
        defer { sqlite3_close(conn) }

        let app = try Database.getAppByName("proxyman", connection: conn)
        XCTAssertNotNil(app)
        XCTAssertEqual(app?.name, "Proxyman")
    }

    func testGetAppByNameReturnsNilForUnknownName() throws {
        let path = createTestDatabase(apps: [
            (name: "Proxyman", bundleID: "com.proxyman.NSProxy", identifier: 100)
        ])

        let conn = try Database.connect(databasePath: path)
        defer { sqlite3_close(conn) }

        let app = try Database.getAppByName("NonExistentApp", connection: conn)
        XCTAssertNil(app)
    }

    func testGetAppByNameIgnoresNullBundleIdentifier() throws {
        let path = createTestDatabase(apps: [
            (name: "GhostApp", bundleID: nil, identifier: 999)
        ])

        let conn = try Database.connect(databasePath: path)
        defer { sqlite3_close(conn) }

        let app = try Database.getAppByName("GhostApp", connection: conn)
        XCTAssertNil(app)
    }

    // MARK: - getAvailableApps

    func testGetAvailableAppsReturnsAllAppsWithBundleIDSorted() throws {
        let path = createTestDatabase(apps: [
            (name: "Proxyman", bundleID: "com.proxyman", identifier: 1),
            (name: "Bartender", bundleID: "com.bartender", identifier: 2),
            (name: "CleanMyMac", bundleID: "com.cleanmymac", identifier: 3)
        ])

        let conn = try Database.connect(databasePath: path)
        defer { sqlite3_close(conn) }

        let apps = try Database.getAvailableApps(connection: conn)
        XCTAssertEqual(apps.count, 3)
        XCTAssertEqual(apps.map(\.name), ["Bartender", "CleanMyMac", "Proxyman"])
    }

    func testGetAvailableAppsReturnsEmptyArrayForEmptyTable() throws {
        let path = createTestDatabase(apps: [])

        let conn = try Database.connect(databasePath: path)
        defer { sqlite3_close(conn) }

        let apps = try Database.getAvailableApps(connection: conn)
        XCTAssertTrue(apps.isEmpty)
    }

    func testGetAvailableAppsExcludesNullBundleIdentifierRows() throws {
        let path = createTestDatabase(apps: [
            (name: "Proxyman", bundleID: "com.proxyman", identifier: 1),
            (name: "GhostApp", bundleID: nil, identifier: 2),
            (name: "Bartender", bundleID: "com.bartender", identifier: 3)
        ])

        let conn = try Database.connect(databasePath: path)
        defer { sqlite3_close(conn) }

        let apps = try Database.getAvailableApps(connection: conn)
        XCTAssertEqual(apps.count, 2)
        XCTAssertEqual(apps.map(\.name), ["Bartender", "Proxyman"])
    }

    func testGetAppByNameWithPassedConnectionDoesNotCloseIt() throws {
        let path = createTestDatabase(apps: [
            (name: "Proxyman", bundleID: "com.proxyman", identifier: 1)
        ])

        let conn = try Database.connect(databasePath: path)

        // First call with the connection
        let app = try Database.getAppByName("Proxyman", connection: conn)
        XCTAssertNotNil(app)

        // Connection should still be usable for a second call
        let apps = try Database.getAvailableApps(connection: conn)
        XCTAssertEqual(apps.count, 1)

        sqlite3_close(conn)
    }
}
