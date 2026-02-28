import ArgumentParser
import Foundation

struct BundleCleanupCommand: ParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "cleanup",
        abstract: "Uninstall Setapp apps not listed in the bundle file."
    )

    @OptionGroup var globals: GlobalOptions

    @Option(name: .shortAndLong, help: "Bundle file path (default: ~/.setapp/bundle).")
    var file: String?

    mutating func run() throws {
        globals.apply()

        let path: URL = BundleFile.resolvePath(flagValue: file)
        let names: [String] = try BundleFile.parse(at: path)
        let bundleSet: Set<String> = Set(names.map { $0.lowercased() })

        let installed: [String] = Dependencies.detector.installedAppNames()
        let extras: [String] = installed.filter { !bundleSet.contains($0.lowercased()) }

        if extras.isEmpty {
            Printer.log("Nothing to clean up.")
            return
        }

        Printer.info("Removing \(extras.count) app(s) not in bundle")

        for name in extras {
            guard let appInfo = try Dependencies.lookup.getAppByName(name) else {
                Printer.error("App not found in Setapp catalogue: \(name)")
                continue
            }

            do {
                try Dependencies.installer.uninstall(appID: appInfo.identifier)
                Printer.log("\(appInfo.name) removed")
            } catch {
                Printer.error("Failed to remove \(appInfo.name): \(error.localizedDescription)")
            }
        }
    }
}
