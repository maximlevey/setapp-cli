import Foundation

/// Live implementation of AppDetecting using filesystem detection.
struct LiveDetector: AppDetecting {
    /// Check if an app is installed.
    func isInstalled(_ name: String) -> Bool {
        SetappDetector.isInstalled(name)
    }

    /// List installed app names.
    func installedAppNames() -> [String] {
        SetappDetector.installedAppNames()
    }

    /// Find a non-Setapp version.
    func findNonSetappApp(named name: String) -> URL? {
        SetappDetector.findNonSetappApp(named: name)
    }

    /// Read bundle ID from app path.
    func readBundleID(at appPath: URL) -> String? {
        SetappDetector.readBundleID(at: appPath)
    }
}
