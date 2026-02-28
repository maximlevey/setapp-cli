import ArgumentParser
import Foundation

@main
struct SetappCLI: ParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "setapp-cli",
        abstract: "Install and manage Setapp apps from the command line.",
        discussion: """
        Common usage:
            setapp-cli install <app>         Install a single app
            setapp-cli list                  List installed apps
            setapp-cli dump                  Save installed apps to a bundle file
            setapp-cli bundle install        Install all apps from a bundle file
            setapp-cli check                 Find apps available via Setapp
        """,
        version: "2.0.0",
        subcommands: [
            InstallCommand.self,
            RemoveCommand.self,
            ReinstallCommand.self,
            ListCommand.self,
            CheckCommand.self,
            DumpCommand.self,
            BundleCommand.self
        ]
    )
}
