import ArgumentParser
import Foundation

struct BundleDumpCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dump",
        abstract: "Write installed apps to a bundle file."
    )

    @OptionGroup var globals: GlobalOptions

    @Option(name: .shortAndLong, help: "Bundle file path (default: ~/.setapp/bundle).")
    var file: String?

    mutating func run() throws {
        globals.apply()

        let appsDirs = URL.setappAppsDirectories
        guard appsDirs.contains(where: { FileManager.default.directoryExists(at: $0.path) }) else {
            throw SetappError.setappAppsDirectoryNotFound(path: appsDirs.map(\.path).joined(separator: ", "))
        }

        let installed = SetappDetector.installedAppNames()
        if installed.isEmpty {
            Printer.warning("No Setapp apps installed")
            return
        }

        let path = BundleFile.resolvePath(flagValue: file)
        Printer.info("Saving \(installed.count) app(s) to \(path.path)")
        try BundleFile.write(names: installed, to: path)
        Printer.log("Wrote \(installed.count) app(s) to \(path.path)")
    }
}
