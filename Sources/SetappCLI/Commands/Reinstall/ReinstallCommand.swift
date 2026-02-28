import ArgumentParser
import Foundation

struct ReinstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reinstall",
        abstract: "Uninstall then reinstall a Setapp app."
    )

    @OptionGroup var globals: GlobalOptions

    @Argument(help: "Name of the app to reinstall.")
    var app: String

    mutating func run() throws {
        globals.apply()

        guard let appInfo = try Database.getAppByName(app) else {
            throw SetappError.appNotFound(name: app)
        }

        Printer.info("Reinstalling \(appInfo.name)")

        if SetappDetector.isInstalled(appInfo.name) {
            try XPCService.uninstall(appID: appInfo.identifier)
            Printer.verbose("\(appInfo.name) removed")
        }

        try XPCService.install(appID: appInfo.identifier)
        Printer.log("\(appInfo.name) reinstalled")
    }
}
