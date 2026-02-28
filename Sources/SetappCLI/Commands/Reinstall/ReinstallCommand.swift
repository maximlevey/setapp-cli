import ArgumentParser
import Foundation

struct ReinstallCommand: ParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "reinstall",
        abstract: "Uninstall then reinstall a Setapp app."
    )

    @OptionGroup var globals: GlobalOptions

    @Argument(help: "Name of the app to reinstall.")
    var app: String

    mutating func run() throws {
        globals.apply()

        guard let appInfo = try Dependencies.lookup.getAppByName(app) else {
            throw SetappError.appNotFound(name: app)
        }

        Printer.info("Reinstalling \(appInfo.name)")

        if Dependencies.detector.isInstalled(appInfo.name) {
            try Dependencies.installer.uninstall(appID: appInfo.identifier)
            Printer.verbose("\(appInfo.name) removed")
        }

        try Dependencies.installer.install(appID: appInfo.identifier)
        Printer.log("\(appInfo.name) reinstalled")
    }
}
