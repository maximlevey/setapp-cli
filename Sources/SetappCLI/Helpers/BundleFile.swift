import Foundation

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

        let content = try String(contentsOf: path, encoding: .utf8)
        return content
            .components(separatedBy: .newlines)
            .map { $0.components(separatedBy: "#").first ?? "" }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Write sorted app names to a bundle file with a header comment.
    static func write(names: [String], to path: URL) throws {
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        let sorted = names.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        var lines = [
            "# setapp bundle -- \(today)",
            "# Run `setapp bundle install` to reinstall on a new Mac.",
            "",
        ]
        lines.append(contentsOf: sorted)
        lines.append("")

        let content = lines.joined(separator: "\n")
        try content.write(to: path, atomically: true, encoding: .utf8)
    }
}
