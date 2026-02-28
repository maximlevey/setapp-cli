import Foundation

/// Protocol for detecting Setapp app installation status.
protocol AppDetecting {
    /// Check if an app is installed (case-insensitive).
    func isInstalled(_ name: String) -> Bool

    /// List all installed Setapp app names, sorted.
    func installedAppNames() -> [String]

    /// Find a non-Setapp version of an app in /Applications or ~/Applications.
    func findNonSetappApp(named name: String) -> URL?

    /// Read CFBundleIdentifier from an .app bundle's Info.plist.
    func readBundleID(at appPath: URL) -> String?
}
