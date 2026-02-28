import ArgumentParser
import Foundation

struct DumpCommand: ParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "dump",
        abstract: "Save installed Setapp apps to a bundle file."
    )

    @OptionGroup var globals: GlobalOptions

    @Option(name: .shortAndLong, help: "Bundle file path (default: ~/.setapp/bundle).")
    var file: String?

    @Flag(name: .shortAndLong, help: "Print app names to stdout instead of writing a file.")
    var list: Bool = false

    mutating func run() throws {
        globals.apply()

        let appsDirs: [URL] = URL.setappAppsDirectories
        guard appsDirs.contains(where: { FileManager.default.directoryExists(at: $0.path) }) else {
            throw SetappError.setappAppsDirectoryNotFound(path: appsDirs.map(\.path).joined(separator: ", "))
        }

        let installed: [String] = SetappDetector.installedAppNames()
        if installed.isEmpty {
            Printer.warning("No Setapp apps installed")
            return
        }

        if list {
            for name in installed {
                Printer.log(name)
            }
            return
        }

        let path: URL = BundleFile.resolvePath(flagValue: file)
        Printer.info("Saving \(installed.count) app(s) to \(path.path)")
        try BundleFile.write(names: installed, to: path)
        Printer.log("Wrote \(installed.count) app(s) to \(path.path)")
    }
}
