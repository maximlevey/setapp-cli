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

        Printer.debug("Querying available apps from database")
        let apps: [SetappApp] = try Dependencies.lookup.getAvailableApps()
        Printer.debug("Found \(apps.count) app(s) in database")
        for app in apps where Dependencies.detector.isInstalled(app.name) {
            Printer.log(app.name)
        }
    }
}
