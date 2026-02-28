import ArgumentParser
import Foundation

struct CheckCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Find locally installed apps that are available via Setapp."
    )

    @OptionGroup var globals: GlobalOptions

    @Flag(name: .shortAndLong, help: "Install each found app via Setapp.")
    var install = false

    mutating func run() throws {
        globals.apply()

        Printer.info("Checking for apps available via Setapp")

        let scanDirs = [
            URL(fileURLWithPath: "/Applications"),
            URL.homeDirectory.appendingPathComponent("Applications"),
        ]

        let available = try Database.getAvailableApps()
        let byBundleID = Dictionary(
            available.map { ($0.bundleIdentifier.replacingOccurrences(of: "-setapp", with: ""), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var found: [SetappApp] = []
        for dir in scanDirs {
            guard FileManager.default.directoryExists(at: dir.path),
                  let contents = try? FileManager.default.contentsOfDirectory(
                      at: dir, includingPropertiesForKeys: nil
                  ) else { continue }

            for appURL in contents where appURL.pathExtension == "app" {
                if let bundleID = SetappDetector.readBundleID(at: appURL),
                   let match = byBundleID[bundleID],
                   !SetappDetector.isInstalled(match.name) {
                    found.append(match)
                }
            }
        }

        if found.isEmpty {
            Printer.log("No apps found that are available via Setapp.")
            return
        }

        Printer.log("Found \(found.count) app(s) available via Setapp:")
        for app in found {
            Printer.log(app.name)
        }

        if install {
            Printer.info("Installing \(found.count) app(s)")
            for app in found {
                try XPCService.install(appID: app.identifier)
                Printer.log("\(app.name) installed")
            }
        }
    }
}
