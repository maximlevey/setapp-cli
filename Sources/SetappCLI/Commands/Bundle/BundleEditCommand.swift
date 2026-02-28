import ArgumentParser
import Foundation

struct BundleEditCommand: ParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "edit",
        abstract: "Open the bundle file in $EDITOR (or 'open' if unset)."
    )

    @OptionGroup var globals: GlobalOptions

    @Option(name: .shortAndLong, help: "Bundle file path (default: ~/.setapp/bundle).")
    var file: String?

    mutating func run() throws {
        globals.apply()

        let path: URL = BundleFile.resolvePath(flagValue: file)

        // Create the file with a header if it doesn't exist.
        if !FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.createDirectory(
                at: path.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let header: String = """
            # setapp bundle
            # Run `setapp bundle install` to reinstall on a new Mac.

            """
            try header.write(to: path, atomically: true, encoding: .utf8)
        }

        let editor: String = ProcessInfo.processInfo.environment["EDITOR"] ?? "open"
        let process: Process = .init()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [editor, path.path]
        try process.run()
        process.waitUntilExit()
    }
}
