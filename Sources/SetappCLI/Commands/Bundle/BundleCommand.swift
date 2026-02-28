import ArgumentParser

struct BundleCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bundle",
        abstract: "Manage bundle files for saving and restoring app lists.",
        discussion: """
        A bundle file is a plain-text list of app names (one per line).
        Use 'bundle dump' on one Mac, then 'bundle install' on another
        to replicate your Setapp app setup.

        Default bundle path: ~/.setapp/bundle
        """,
        subcommands: [
            BundleInstallCommand.self,
            BundleDumpCommand.self,
            BundleListCommand.self,
            BundleCheckCommand.self,
            BundleCleanupCommand.self,
            BundleEditCommand.self,
        ]
    )
}
