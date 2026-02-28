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

        sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)

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
}
