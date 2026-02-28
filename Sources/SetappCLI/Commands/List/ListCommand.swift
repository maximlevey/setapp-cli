import ArgumentParser
import Foundation

struct ListCommand: ParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "list",
        abstract: "List installed Setapp apps."
    )

    @OptionGroup var globals: GlobalOptions

    mutating func run() throws {
        globals.apply()

        let apps: [SetappApp] = try Dependencies.lookup.getAvailableApps()
        for app in apps where Dependencies.detector.isInstalled(app.name) {
            Printer.log(app.name)
        }
    }
}
