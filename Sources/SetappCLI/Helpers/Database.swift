import Foundation
import SQLite3

/// Setapp SQLite database access layer.
enum Database {
    /// Open the Setapp SQLite database (read-only).
    /// - Parameter databasePath: Path to the SQLite file. Defaults to the standard Setapp database location.
    static func connect(databasePath: String = URL.setappDatabase.path) throws -> OpaquePointer {
        let path: String = databasePath

        guard FileManager.default.fileExists(atPath: path) else {
            throw SetappError.databaseNotFound(path: path)
        }

        var connection: OpaquePointer?
        let flags: Int32 = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX

        guard sqlite3_open_v2(path, &connection, flags, nil) == SQLITE_OK, let connection else {
            let message: String = connection.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            throw SetappError.databaseQueryFailed(message: message)
        }

        return connection
    }

    /// Find an app by name (case-insensitive).
    static func getAppByName(_ name: String, connection: OpaquePointer? = nil) throws -> SetappApp? {
        let database: OpaquePointer = try connection ?? connect()
        defer { if connection == nil { sqlite3_close(database) } }

        let sql: String = """
        SELECT ZNAME, ZBUNDLEIDENTIFIER, ZIDENTIFIER FROM ZAPP
        WHERE ZBUNDLEIDENTIFIER IS NOT NULL AND LOWER(ZNAME) = LOWER(?)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SetappError.databaseQueryFailed(
                message: String(cString: sqlite3_errmsg(database))
            )
        }
        defer { sqlite3_finalize(stmt) }

        // NSString local required: sqlite3_bind_text with SQLITE_STATIC (nil destructor) requires
        // the pointer to remain valid until sqlite3_step completes. A named binding prevents ARC
        // from releasing the NSString before the C call returns.
        let nameNS: NSString = name as NSString
        sqlite3_bind_text(stmt, 1, nameNS.utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }

        return SetappApp(
            name: String(cString: sqlite3_column_text(stmt, 0)),
            bundleIdentifier: String(cString: sqlite3_column_text(stmt, 1)),
            identifier: Int(sqlite3_column_int64(stmt, 2))
        )
    }

    /// Return all available apps sorted by name.
    static func getAvailableApps(connection: OpaquePointer? = nil) throws -> [SetappApp] {
        let database: OpaquePointer = try connection ?? connect()
        defer { if connection == nil { sqlite3_close(database) } }

        let sql: String = """
        SELECT ZNAME, ZBUNDLEIDENTIFIER, ZIDENTIFIER FROM ZAPP
        WHERE ZBUNDLEIDENTIFIER IS NOT NULL ORDER BY LOWER(ZNAME)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SetappError.databaseQueryFailed(
                message: String(cString: sqlite3_errmsg(database))
            )
        }
        defer { sqlite3_finalize(stmt) }

        var apps: [SetappApp] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            apps.append(SetappApp(
                name: String(cString: sqlite3_column_text(stmt, 0)),
                bundleIdentifier: String(cString: sqlite3_column_text(stmt, 1)),
                identifier: Int(sqlite3_column_int64(stmt, 2))
            ))
        }
        return apps
    }

    /// Search apps by name, tagline, or keywords, with optional category filter.
    ///
    /// - Parameters:
    ///   - query: Search term for `LIKE '%query%'` match against name, tagline, and keywords.
    ///   - category: If non-nil, only return apps in the given Setapp category (exact ZSETAPPCATEGORY.ZNAME match).
    ///   - connection: Optional existing connection; a new one is opened and closed if nil.
    /// - Returns: Matching apps sorted by name, each with `tagline` populated.
    static func searchApps(
        query: String,
        category: String?,
        connection: OpaquePointer? = nil
    ) throws -> [SetappApp] {
        let database: OpaquePointer = try connection ?? connect()
        defer { if connection == nil { sqlite3_close(database) } }

        let pattern: String = "%\(query)%"

        let sql: String
        if category != nil {
            sql = """
            SELECT DISTINCT a.ZNAME, a.ZBUNDLEIDENTIFIER, a.ZIDENTIFIER, a.ZTAGLINE
            FROM ZAPP a
            JOIN Z_1SETAPPCATEGORIES j ON j.Z_1APPLICATIONS = a.Z_PK
            JOIN ZSETAPPCATEGORY c ON c.Z_PK = j.Z_20SETAPPCATEGORIES
            WHERE a.ZBUNDLEIDENTIFIER IS NOT NULL
              AND (
                LOWER(a.ZNAME) LIKE LOWER(?)
                OR LOWER(a.ZTAGLINE) LIKE LOWER(?)
                OR LOWER(a.ZJOINEDKEYWORDS) LIKE LOWER(?)
              )
              AND LOWER(c.ZNAME) = LOWER(?)
            ORDER BY LOWER(a.ZNAME)
            """
        } else {
            sql = """
            SELECT a.ZNAME, a.ZBUNDLEIDENTIFIER, a.ZIDENTIFIER, a.ZTAGLINE
            FROM ZAPP a
            WHERE a.ZBUNDLEIDENTIFIER IS NOT NULL
              AND (
                LOWER(a.ZNAME) LIKE LOWER(?)
                OR LOWER(a.ZTAGLINE) LIKE LOWER(?)
                OR LOWER(a.ZJOINEDKEYWORDS) LIKE LOWER(?)
              )
            ORDER BY LOWER(a.ZNAME)
            """
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SetappError.databaseQueryFailed(
                message: String(cString: sqlite3_errmsg(database))
            )
        }
        defer { sqlite3_finalize(stmt) }

        // NSString local required: see getAppByName comment above.
        let patternNS: NSString = pattern as NSString
        let patternPtr: UnsafePointer<CChar>? = patternNS.utf8String
        sqlite3_bind_text(stmt, 1, patternPtr, -1, nil)
        sqlite3_bind_text(stmt, 2, patternPtr, -1, nil)
        sqlite3_bind_text(stmt, 3, patternPtr, -1, nil)
        if let category: String = category {
            let categoryNS: NSString = category as NSString
            sqlite3_bind_text(stmt, 4, categoryNS.utf8String, -1, nil)
        }

        var apps: [SetappApp] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let taglinePtr: UnsafePointer<UInt8>? = sqlite3_column_text(stmt, 3)
            let tagline: String? = taglinePtr.map { String(cString: $0) }
            apps.append(SetappApp(
                name: String(cString: sqlite3_column_text(stmt, 0)),
                bundleIdentifier: String(cString: sqlite3_column_text(stmt, 1)),
                identifier: Int(sqlite3_column_int64(stmt, 2)),
                tagline: tagline
            ))
        }
        return apps
    }
}
