import Foundation

/// AppList file read/write operations.
enum AppListFile {
    /// Resolve AppList file path from flag value, env var, or default.
    static func resolvePath(flagValue: String?) -> URL {
        if let flagValue, !flagValue.isEmpty {
            return URL(fileURLWithPath: (flagValue as NSString).expandingTildeInPath)
        }
        if let envPath = ProcessInfo.processInfo.environment["SETAPP_APP_LIST_FILE"] {
            return URL(fileURLWithPath: (envPath as NSString).expandingTildeInPath)
        }
        return URL.defaultAppListPath
    }

    /// Parse an AppList file, returning app names (comments and blanks stripped).
    static func parse(at path: URL) throws -> [String] {
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw SetappError.appListFileNotFound(path: path.path)
        }

        let content: String = try String(contentsOf: path, encoding: .utf8)
        return content
            .components(separatedBy: .newlines)
            .map { $0.components(separatedBy: "#").first ?? "" }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Verify Setapp directories exist and return installed app names, or throw/warn.
    ///
    /// - Returns: Installed app names, or an empty array if none are installed (after printing a warning).
    static func fetchInstalledNames() throws -> [String] {
        let appsDirs: [URL] = URL.setappAppsDirectories
        guard appsDirs.contains(where: { FileManager.default.directoryExists(at: $0.path) }) else {
            throw SetappError.setappAppsDirectoryNotFound(
                path: appsDirs.map(\.path).joined(separator: ", ")
            )
        }

        let installed: [String] = Dependencies.detector.installedAppNames()
        if installed.isEmpty {
            Printer.warning("No Setapp apps installed")
        }
        return installed
    }

    /// Write sorted app names to an AppList file (no header, one name per line).
    static func write(names: [String], to path: URL) throws {
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let sorted: [String] = names.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        let content: String = sorted.joined(separator: "\n") + "\n"
        try content.write(to: path, atomically: true, encoding: .utf8)
    }
}
