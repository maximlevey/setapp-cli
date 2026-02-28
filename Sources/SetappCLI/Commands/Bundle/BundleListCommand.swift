import ArgumentParser
import Foundation

struct BundleListCommand: ParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "list",
        abstract: "List apps in the bundle file."
    )

    @OptionGroup var globals: GlobalOptions

    @Option(name: .shortAndLong, help: "Bundle file path (default: ~/.setapp/bundle).")
    var file: String?

    mutating func run() throws {
        globals.apply()
        try Dependencies.verifyEnvironment()

        let path: URL = BundleFile.resolvePath(flagValue: file)
        let names: [String] = try BundleFile.parse(at: path)
        for name in names {
            Printer.log(name)
        }
    }
}
