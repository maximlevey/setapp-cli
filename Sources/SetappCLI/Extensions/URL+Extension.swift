import Foundation

extension URL {
    /// The user's home directory.
    static var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    /// The Setapp config directory (~/.setapp/).
    static var setappDirectory: URL {
        homeDirectory.appendingPathComponent(".setapp")
    }

    /// The default bundle file path (~/.setapp/bundle).
    static var defaultBundlePath: URL {
        setappDirectory.appendingPathComponent("bundle")
    }

    /// Setapp apps directories — admin (/Applications/Setapp/) and
    /// standard user (~/Applications/Setapp/).
    static var setappAppsDirectories: [URL] {
        [
            URL(fileURLWithPath: "/Applications/Setapp"),
            homeDirectory.appendingPathComponent("Applications/Setapp")
        ]
    }

    /// The Setapp SQLite database path.
    static var setappDatabase: URL {
        homeDirectory.appendingPathComponent(
            "Library/Application Support/Setapp/Default/Databases/Apps.sqlite"
        )
    }

    /// The Setapp frameworks directory.
    static var setappFrameworks: URL {
        homeDirectory.appendingPathComponent(
            "Library/Application Support/Setapp/LaunchAgents/Setapp.app/Contents/Frameworks"
        )
    }
}
