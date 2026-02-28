import ArgumentParser
import Foundation

struct BundleInstallCommand: ParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "install",
        abstract: "Install all apps from a AppList file."
    )

    @OptionGroup var globals: GlobalOptions

    @Option(name: .shortAndLong, help: "AppList file path (default: ~/.setapp/AppList).")
    var file: String?

    @Flag(name: .long, help: "Remove the non-Setapp version from /Applications after install.")
    var replace: Bool = false

    mutating func run() throws {
        globals.apply()
        try Dependencies.verifyEnvironment()

        let path: URL = AppListFile.resolvePath(flagValue: file)
        let names: [String] = try AppListFile.parse(at: path)

        if names.isEmpty {
            Printer.warning("AppList file is empty: \(path.path)")
            return
        }

        Printer.info("Installing \(names.count) app(s) from \(path.path)")

        for name in names {
            if Dependencies.detector.isInstalled(name) {
                Printer.verbose("\(name) is already installed, skipping")
                continue
            }

            guard let appInfo = try Dependencies.lookup.getAppByName(name) else {
                Printer.error("App not found in Setapp catalogue: \(name)")
                continue
            }

            let replacePath: URL? = replace ? Dependencies.detector.findNonSetappApp(named: appInfo.name) : nil

            do {
                try Dependencies.installer.install(appID: appInfo.identifier)
                Printer.log("\(appInfo.name) installed")

                if let path = replacePath, FileManager.default.fileExists(atPath: path.path) {
                    try? FileManager.default.removeItem(at: path)
                    Printer.verbose("Removed \(path.path)")
                }
            } catch {
                Printer.error("Failed to install \(appInfo.name): \(error.localizedDescription)")
            }
        }
    }
}
