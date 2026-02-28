import ArgumentParser
import Foundation

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List installed Setapp apps."
    )

    @OptionGroup var globals: GlobalOptions

    mutating func run() throws {
        globals.apply()

        let apps = try Database.getAvailableApps()
        for app in apps where SetappDetector.isInstalled(app.name) {
            Printer.log(app.name)
        }
    }
}
