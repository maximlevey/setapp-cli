import ArgumentParser

struct BundleCommand: ParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "bundle",
        abstract: "Manage AppList files for saving and restoring app lists.",
        discussion: """
        An AppList file is a plain-text list of app names (one per line).
        Use 'bundle dump' on one Mac, then 'bundle install' on another
        to replicate your Setapp app setup.

        Default AppList path: ~/.setapp/AppList
        """,
        subcommands: [
            BundleInstallCommand.self,
            BundleDumpCommand.self,
            BundleListCommand.self,
            BundleCheckCommand.self,
            BundleCleanupCommand.self,
            BundleEditCommand.self
        ]
    )
}
