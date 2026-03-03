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
            setapp-cli search <query>        Search the Setapp catalogue
            setapp-cli list                  List installed apps
            setapp-cli bundle dump           Save installed apps to a AppList file
            setapp-cli bundle install        Install all apps from a AppList file
            setapp-cli check                 Find apps available via Setapp
        """,
        version: "2.2.0",
        subcommands: [
            InstallCommand.self,
            RemoveCommand.self,
            ReinstallCommand.self,
            ListCommand.self,
            SearchCommand.self,
            CheckCommand.self,
            BundleCommand.self
        ]
    )
}
