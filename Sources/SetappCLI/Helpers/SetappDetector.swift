import Foundation

enum SetappDetector {

    /// Check if an app is installed in any Setapp apps directory (case-insensitive).
    static func isInstalled(_ name: String, appsDirs: [URL] = URL.setappAppsDirectories) -> Bool {
        let target = name.lowercased()
        for dir in appsDirs {
            guard FileManager.default.directoryExists(at: dir.path),
                  let contents = try? FileManager.default.contentsOfDirectory(
                      at: dir, includingPropertiesForKeys: nil
                  ) else { continue }

            if contents.contains(where: {
                $0.pathExtension == "app"
                    && $0.deletingPathExtension().lastPathComponent.lowercased() == target
            }) {
                return true
            }
        }
        return false
    }

    /// Read CFBundleIdentifier from an .app bundle's Info.plist.
    static func readBundleID(at appPath: URL) -> String? {
        let plistURL = appPath
            .appendingPathComponent("Contents")
            .appendingPathComponent("Info.plist")

        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data, format: nil
              ) as? [String: Any] else {
            return nil
        }
        return plist["CFBundleIdentifier"] as? String
    }

    /// Find a non-Setapp version of an app in /Applications or ~/Applications.
    static func findNonSetappApp(named name: String) -> URL? {
        let candidates = [
            URL(fileURLWithPath: "/Applications/\(name).app"),
            URL.homeDirectory.appendingPathComponent("Applications/\(name).app"),
        ]
        return candidates.first { FileManager.default.directoryExists(at: $0.path) }
    }

    /// List all installed Setapp app names across all Setapp directories, sorted alphabetically.
    static func installedAppNames(appsDirs: [URL] = URL.setappAppsDirectories) -> [String] {
        var names: [String] = []
        for dir in appsDirs {
            guard FileManager.default.directoryExists(at: dir.path),
                  let contents = try? FileManager.default.contentsOfDirectory(
                      at: dir, includingPropertiesForKeys: nil
                  ) else { continue }

            names += contents
                .filter { $0.pathExtension == "app" }
                .map { $0.deletingPathExtension().lastPathComponent }
        }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
