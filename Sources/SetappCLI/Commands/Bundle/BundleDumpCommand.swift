import ArgumentParser
import Foundation

struct BundleDumpCommand: ParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "dump",
        abstract: "Write installed apps to a bundle file."
    )

    @OptionGroup var globals: GlobalOptions

    @Option(name: .shortAndLong, help: "AppList file path (default: ~/.setapp/AppList).")
    var file: String?

    @Flag(name: .shortAndLong, help: "Print app names to stdout instead of writing a file.")
    var list: Bool = false

    mutating func run() throws {
        globals.apply()
        try Dependencies.verifyEnvironment()

        let installed: [String] = try AppListFile.fetchInstalledNames()
        if installed.isEmpty {
            return
        }

        if list {
            for name in installed {
                Printer.log(name)
            }
            return
        }

        let path: URL = AppListFile.resolvePath(flagValue: file)
        Printer.info("Saving \(installed.count) app(s) to \(path.path)")
        try AppListFile.write(names: installed, to: path)
        Printer.log("Wrote \(installed.count) app(s) to \(path.path)")
    }
}
