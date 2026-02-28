import ArgumentParser
import Foundation

struct BundleInstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install all apps from a bundle file."
    )

    @OptionGroup var globals: GlobalOptions

    @Option(name: .shortAndLong, help: "Bundle file path (default: ~/.setapp/bundle).")
    var file: String?

    @Flag(name: .long, help: "Remove the non-Setapp version from /Applications after install.")
    var replace = false

    mutating func run() throws {
        globals.apply()

        let path = BundleFile.resolvePath(flagValue: file)
        let names = try BundleFile.parse(at: path)

        if names.isEmpty {
            Printer.warning("Bundle file is empty: \(path.path)")
            return
        }

        Printer.info("Installing \(names.count) app(s) from \(path.path)")

        for name in names {
            if SetappDetector.isInstalled(name) {
                Printer.verbose("\(name) is already installed, skipping")
                continue
            }

            guard let appInfo = try Database.getAppByName(name) else {
                Printer.error("App not found in Setapp catalogue: \(name)")
                continue
            }

            let replacePath = replace ? SetappDetector.findNonSetappApp(named: appInfo.name) : nil

            do {
                try XPCService.install(appID: appInfo.identifier)
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
