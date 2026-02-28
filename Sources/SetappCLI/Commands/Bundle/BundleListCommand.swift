import ArgumentParser
import Foundation

struct BundleListCommand: ParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "list",
        abstract: "List apps in the AppList file."
    )

    @OptionGroup var globals: GlobalOptions

    @Option(name: .shortAndLong, help: "AppList file path (default: ~/.setapp/AppList).")
    var file: String?

    mutating func run() throws {
        globals.apply()
        try Dependencies.verifyEnvironment()

        let path: URL = AppListFile.resolvePath(flagValue: file)
        let names: [String] = try AppListFile.parse(at: path)
        for name in names {
            Printer.log(name)
        }
    }
}
