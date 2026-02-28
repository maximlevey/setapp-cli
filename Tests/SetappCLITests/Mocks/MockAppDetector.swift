import Foundation
@testable import SetappCLI

final class MockAppDetector: AppDetecting {
    var installedNames: Set<String> = []
    var allInstalledNames: [String] = []
    var nonSetappPaths: [String: URL] = [:]
    var bundleIDs: [URL: String] = [:]

    func isInstalled(_ name: String) -> Bool {
        installedNames.contains(name)
    }

    func installedAppNames() -> [String] {
        allInstalledNames.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    func findNonSetappApp(named name: String) -> URL? {
        nonSetappPaths[name]
    }

    func readBundleID(at appPath: URL) -> String? {
        bundleIDs[appPath]
    }
}
