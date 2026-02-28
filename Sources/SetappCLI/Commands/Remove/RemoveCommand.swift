import ArgumentParser
import Foundation

struct RemoveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Uninstall a Setapp app."
    )

    @OptionGroup var globals: GlobalOptions

    @Argument(help: "Name of the app to remove.")
    var app: String

    mutating func run() throws {
        globals.apply()

        guard let appInfo = try Database.getAppByName(app) else {
            throw SetappError.appNotFound(name: app)
        }

        guard SetappDetector.isInstalled(appInfo.name) else {
            throw SetappError.appNotInstalled(name: appInfo.name)
        }

        Printer.info("Removing \(appInfo.name)")
        try XPCService.uninstall(appID: appInfo.identifier)
        Printer.log("\(appInfo.name) removed")
    }
}
