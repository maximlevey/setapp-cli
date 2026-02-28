import ArgumentParser
import Foundation

struct RemoveCommand: ParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "remove",
        abstract: "Uninstall a Setapp app."
    )

    @OptionGroup var globals: GlobalOptions

    @Argument(help: "Name of the app to remove.")
    var app: String

    mutating func run() throws {
        globals.apply()

        guard let appInfo = try Dependencies.lookup.getAppByName(app) else {
            throw SetappError.appNotFound(name: app)
        }

        guard Dependencies.detector.isInstalled(appInfo.name) else {
            throw SetappError.appNotInstalled(name: appInfo.name)
        }

        Printer.info("Removing \(appInfo.name)")
        try Dependencies.installer.uninstall(appID: appInfo.identifier)
        Printer.log("\(appInfo.name) removed")
    }
}
