import ArgumentParser
import Foundation

struct BundleCheckCommand: ParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "check",
        abstract: "Check that all AppList apps are installed (exit 1 if any missing)."
    )

    @OptionGroup var globals: GlobalOptions

    @Option(name: .shortAndLong, help: "AppList file path (default: ~/.setapp/AppList).")
    var file: String?

    @Option(name: .shortAndLong, help: "Directory to check for installed apps (default: /Applications and ~/Applications).")
    var path: String?

    mutating func run() throws {
        globals.apply()
        try Dependencies.verifyEnvironment()

        let listPath: URL = AppListFile.resolvePath(flagValue: file)
        let names: [String] = try AppListFile.parse(at: listPath)
        let missing: [String] = names.filter { !isInstalled($0) }

        if missing.isEmpty {
            Printer.log("All AppList apps are installed.")
            return
        }

        Printer.warning("\(missing.count) app(s) from AppList are not installed:")
        for name in missing {
            Printer.log(name)
        }
        throw ExitCode(1)
    }

    /// Returns true if `name.app` exists in the search path(s).
    private func isInstalled(_ name: String) -> Bool {
        if let searchPath: String = path {
            let expanded: String = (searchPath as NSString).expandingTildeInPath
            return FileManager.default.fileExists(atPath: "\(expanded)/\(name).app")
        }
        let dirs: [String] = [
            "/Applications",
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications").path
        ]
        return dirs.contains { dir in
            FileManager.default.fileExists(atPath: "\(dir)/\(name).app")
        }
    }
}
