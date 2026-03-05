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

    /// A richer app fixture that includes all columns used by `searchApps`.
    private struct AppFixture {
        /// Display name.
        var name: String
        /// Bundle identifier (nil rows are excluded by the query).
        var bundleID: String?
        /// Setapp numeric identifier.
        var identifier: Int
        /// Explicit primary key used for join tables.
        var pk: Int
        /// Short description.
        var tagline: String?
        /// Space-joined keyword string.
        var keywords: String?
    }

    /// Create a temporary SQLite database with the full Setapp schema for `searchApps` tests.
    ///
    /// - Parameters:
    ///   - apps: App rows to insert into `ZAPP`.
    ///   - categories: Optional category names keyed by their primary key.
    ///   - appCategoryLinks: Optional (appPK, categoryPK) pairs for the join table.
    /// - Returns: Path to the temporary SQLite file.
    private func createSearchTestDatabase(
        apps: [AppFixture],
        categories: [(pk: Int, name: String)] = [],
        appCategoryLinks: [(appPK: Int, categoryPK: Int)] = []
    ) -> String {
        let path = NSTemporaryDirectory() + UUID().uuidString + ".sqlite"
        tempDatabasePaths.append(path)

        var database: OpaquePointer?
        sqlite3_open(path, &database)

        sqlite3_exec(
            database,
            """
            CREATE TABLE ZAPP (
                Z_PK INTEGER PRIMARY KEY,
                ZNAME TEXT,
                ZBUNDLEIDENTIFIER TEXT,
                ZIDENTIFIER INTEGER,
                ZTAGLINE TEXT,
                ZJOINEDKEYWORDS TEXT
            )
            """,
            nil, nil, nil
        )

        for app in apps {
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(
                database,
                """
                INSERT INTO ZAPP
                    (Z_PK, ZNAME, ZBUNDLEIDENTIFIER, ZIDENTIFIER, ZTAGLINE, ZJOINEDKEYWORDS)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                -1, &stmt, nil
            )
            sqlite3_bind_int64(stmt, 1, Int64(app.pk))
            sqlite3_bind_text(stmt, 2, (app.name as NSString).utf8String, -1, nil)
            if let bid = app.bundleID {
                sqlite3_bind_text(stmt, 3, (bid as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 3)
            }
            sqlite3_bind_int64(stmt, 4, Int64(app.identifier))
            if let tagline = app.tagline {
                sqlite3_bind_text(stmt, 5, (tagline as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 5)
            }
            if let keywords = app.keywords {
                sqlite3_bind_text(stmt, 6, (keywords as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 6)
            }
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }

        if !categories.isEmpty || !appCategoryLinks.isEmpty {
            sqlite3_exec(
                database,
                "CREATE TABLE ZSETAPPCATEGORY (Z_PK INTEGER PRIMARY KEY, ZNAME TEXT)",
                nil, nil, nil
            )
            for cat in categories {
                var stmt: OpaquePointer?
                sqlite3_prepare_v2(
                    database,
                    "INSERT INTO ZSETAPPCATEGORY (Z_PK, ZNAME) VALUES (?, ?)",
                    -1, &stmt, nil
                )
                sqlite3_bind_int64(stmt, 1, Int64(cat.pk))
                sqlite3_bind_text(stmt, 2, (cat.name as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }

            sqlite3_exec(
                database,
                """
                CREATE TABLE Z_1SETAPPCATEGORIES (
                    Z_1APPLICATIONS INTEGER,
                    Z_20SETAPPCATEGORIES INTEGER
                )
                """,
                nil, nil, nil
            )
            for link in appCategoryLinks {
                var stmt: OpaquePointer?
                sqlite3_prepare_v2(
                    database,
                    "INSERT INTO Z_1SETAPPCATEGORIES (Z_1APPLICATIONS, Z_20SETAPPCATEGORIES) VALUES (?, ?)",
                    -1, &stmt, nil
                )
                sqlite3_bind_int64(stmt, 1, Int64(link.appPK))
                sqlite3_bind_int64(stmt, 2, Int64(link.categoryPK))
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
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

    // MARK: - searchApps

    func testSearchByName() throws {
        let path = createSearchTestDatabase(apps: [
            AppFixture(name: "Proxyman", bundleID: "com.proxyman", identifier: 1, pk: 1, tagline: "Network debugger"),
            AppFixture(name: "Bartender", bundleID: "com.bartender", identifier: 2, pk: 2, tagline: "Menu bar organizer")
        ])

        let conn = try Database.connect(databasePath: path)
        defer { sqlite3_close(conn) }

        let results = try Database.searchApps(query: "Proxy", category: nil, connection: conn)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Proxyman")
        XCTAssertEqual(results[0].tagline, "Network debugger")
    }

    func testSearchByTagline() throws {
        let path = createSearchTestDatabase(apps: [
            AppFixture(name: "Proxyman", bundleID: "com.proxyman", identifier: 1, pk: 1, tagline: "Network debugger"),
            AppFixture(name: "Bartender", bundleID: "com.bartender", identifier: 2, pk: 2, tagline: "Menu bar organizer")
        ])

        let conn = try Database.connect(databasePath: path)
        defer { sqlite3_close(conn) }

        let results = try Database.searchApps(query: "Menu bar", category: nil, connection: conn)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Bartender")
    }

    func testSearchByKeywords() throws {
        let path = createSearchTestDatabase(apps: [
            AppFixture(
                name: "CleanMyMac",
                bundleID: "com.cleanmymac",
                identifier: 3,
                pk: 3,
                tagline: "Mac maintenance",
                keywords: "cleaner optimizer junk disk"
            ),
            AppFixture(name: "Proxyman", bundleID: "com.proxyman", identifier: 1, pk: 1, tagline: "Network debugger")
        ])

        let conn = try Database.connect(databasePath: path)
        defer { sqlite3_close(conn) }

        let results = try Database.searchApps(query: "optimizer", category: nil, connection: conn)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "CleanMyMac")
    }

    func testSearchWithCategoryFilter() throws {
        let path = createSearchTestDatabase(
            apps: [
                AppFixture(name: "Proxyman", bundleID: "com.proxyman", identifier: 1, pk: 1, tagline: "Network debugger"),
                AppFixture(name: "Bartender", bundleID: "com.bartender", identifier: 2, pk: 2, tagline: "Menu bar organizer")
            ],
            categories: [
                (pk: 10, name: "Developer Tools"),
                (pk: 20, name: "Utilities")
            ],
            appCategoryLinks: [
                (appPK: 1, categoryPK: 10),
                (appPK: 2, categoryPK: 20)
            ]
        )

        let conn = try Database.connect(databasePath: path)
        defer { sqlite3_close(conn) }

        let results = try Database.searchApps(query: "", category: "Developer Tools", connection: conn)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Proxyman")
    }

    func testSearchEmptyQuery() throws {
        let path = createSearchTestDatabase(apps: [
            AppFixture(name: "Proxyman", bundleID: "com.proxyman", identifier: 1, pk: 1),
            AppFixture(name: "Bartender", bundleID: "com.bartender", identifier: 2, pk: 2),
            AppFixture(name: "CleanMyMac", bundleID: "com.cleanmymac", identifier: 3, pk: 3)
        ])

        let conn = try Database.connect(databasePath: path)
        defer { sqlite3_close(conn) }

        let results = try Database.searchApps(query: "", category: nil, connection: conn)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results.map(\.name), ["Bartender", "CleanMyMac", "Proxyman"])
    }

    func testSearchNoResults() throws {
        let path = createSearchTestDatabase(apps: [
            AppFixture(name: "Proxyman", bundleID: "com.proxyman", identifier: 1, pk: 1),
            AppFixture(name: "Bartender", bundleID: "com.bartender", identifier: 2, pk: 2)
        ])

        let conn = try Database.connect(databasePath: path)
        defer { sqlite3_close(conn) }

        let results = try Database.searchApps(query: "xyznonexistent", category: nil, connection: conn)
        XCTAssertTrue(results.isEmpty)
    }
}
