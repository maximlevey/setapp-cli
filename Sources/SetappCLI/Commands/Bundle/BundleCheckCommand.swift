import ArgumentParser
import Foundation

struct BundleCheckCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Check that all bundle apps are installed (exit 1 if any missing)."
    )

    @OptionGroup var globals: GlobalOptions

    @Option(name: .shortAndLong, help: "Bundle file path (default: ~/.setapp/bundle).")
    var file: String?

    mutating func run() throws {
        globals.apply()

        let path = BundleFile.resolvePath(flagValue: file)
        let names = try BundleFile.parse(at: path)
        let missing = names.filter { !SetappDetector.isInstalled($0) }

        if missing.isEmpty {
            Printer.log("All bundle apps are installed.")
            return
        }

        Printer.warning("\(missing.count) app(s) from bundle are not installed:")
        for name in missing {
            Printer.log(name)
        }
        throw ExitCode(1)
    }
}
