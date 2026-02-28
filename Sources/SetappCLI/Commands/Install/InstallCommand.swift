import ArgumentParser
import Foundation

struct InstallCommand: ParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "install",
        abstract: "Install a Setapp app by name."
    )

    @OptionGroup var globals: GlobalOptions

    @Argument(help: "Name of the app to install (e.g. \"Proxyman\").")
    var app: String

    @Flag(name: .long, help: "Remove the non-Setapp version from /Applications after install.")
    var replace: Bool = false

    mutating func run() throws {
        globals.apply()

        if SetappDetector.isInstalled(app) {
            Printer.warning("\(app) is already installed")
            return
        }

        guard let appInfo = try Database.getAppByName(app) else {
            throw SetappError.appNotFound(name: app)
        }

        Printer.info("Installing \(appInfo.name)")

        let replacePath: URL? = replace ? SetappDetector.findNonSetappApp(named: appInfo.name) : nil
        if let path = replacePath {
            Printer.verbose("Will replace \(path.path) after install")
        }

        try XPCService.install(appID: appInfo.identifier)
        Printer.log("\(appInfo.name) installed")

        if let path = replacePath, FileManager.default.fileExists(atPath: path.path) {
            try? FileManager.default.removeItem(at: path)
            Printer.verbose("Removed \(path.path)")
        }
    }
}
