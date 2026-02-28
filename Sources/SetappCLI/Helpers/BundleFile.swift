import Foundation

/// Bundle file read/write operations.
enum BundleFile {
    /// Resolve bundle file path from flag value, env var, or default.
    static func resolvePath(flagValue: String?) -> URL {
        if let flagValue, !flagValue.isEmpty {
            return URL(fileURLWithPath: (flagValue as NSString).expandingTildeInPath)
        }
        if let envPath = ProcessInfo.processInfo.environment["SETAPP_BUNDLE_FILE"] {
            return URL(fileURLWithPath: (envPath as NSString).expandingTildeInPath)
        }
        return URL.defaultBundlePath
    }

    /// Parse a bundle file, returning app names (comments and blanks stripped).
    static func parse(at path: URL) throws -> [String] {
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw SetappError.bundleFileNotFound(path: path.path)
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
    /// Shared by DumpCommand and BundleDumpCommand.
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

    /// Write sorted app names to a bundle file with a header comment.
    static func write(names: [String], to path: URL) throws {
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let formatter: DateFormatter = .init()
        formatter.dateFormat = "yyyy-MM-dd"
        let today: String = formatter.string(from: Date())

        let sorted: [String] = names.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        var lines: [String] = [
            "# setapp bundle -- \(today)",
            "# Run `setapp bundle install` to reinstall on a new Mac.",
            ""
        ]
        lines.append(contentsOf: sorted)
        lines.append("")

        let content: String = lines.joined(separator: "\n")
        try content.write(to: path, atomically: true, encoding: .utf8)
    }
}
