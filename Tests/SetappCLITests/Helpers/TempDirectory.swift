import Foundation

final class TempDirectory {
    let url: URL

    init() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(
            at: tmp,
            withIntermediateDirectories: true
        )
        url = tmp
    }

    /// Create a fake .app bundle directory with an optional Info.plist.
    func createFakeApp(named name: String, bundleID: String? = nil) -> URL {
        let appDir = url
            .appendingPathComponent("\(name).app")
            .appendingPathComponent("Contents")
        try? FileManager.default.createDirectory(
            at: appDir,
            withIntermediateDirectories: true
        )

        if let bundleID {
            let plist: [String: Any] = ["CFBundleIdentifier": bundleID]
            let data = try? PropertyListSerialization.data(
                fromPropertyList: plist,
                format: .xml,
                options: 0
            )
            let plistURL = appDir.appendingPathComponent("Info.plist")
            try? data?.write(to: plistURL)
        }

        return url.appendingPathComponent("\(name).app")
    }

    /// Create a text file at a given relative path.
    func createFile(named name: String, content: String) -> URL {
        let fileURL = url.appendingPathComponent(name)
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}
