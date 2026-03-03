import ArgumentParser
import Foundation

/// Setapp catalogue category filter values.
enum AppCategory: String, ExpressibleByArgument, CaseIterable {
    /// Developer tools.
    case develop
    /// Productivity and system utilities.
    case optimize
    /// Work and office tools.
    case work
    /// Creative tools.
    case create
    /// AI-powered apps.
    case ai

    /// The matching ZSETAPPCATEGORY.ZNAME value in the Setapp database.
    var dbName: String {
        switch self {
        case .develop: "Develop"
        case .optimize: "Optimize"
        case .work: "Work"
        case .create: "Create"
        case .ai: "Solve with AI+"
        }
    }
}

struct SearchCommand: ParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "search",
        abstract: "Search the Setapp catalogue."
    )

    @OptionGroup var globals: GlobalOptions

    /// The search query matched against app name, tagline, and keywords.
    @Argument(help: "Search term.")
    var query: String

    /// Restrict results to a single category.
    @Option(name: .long, help: "Filter by category: develop, optimize, work, create, ai.")
    var category: AppCategory?

    /// Hide apps that are already installed.
    @Flag(name: .long, help: "Show only apps that are not installed.")
    var notInstalled: Bool = false

    mutating func run() throws {
        globals.apply()
        try Dependencies.verifyEnvironment()

        let results: [SetappApp] = try Dependencies.lookup.searchApps(
            query: query,
            category: category?.dbName
        )

        let filtered: [SetappApp] = notInstalled
            ? results.filter { !Dependencies.detector.isInstalled($0.name) }
            : results

        if filtered.isEmpty {
            Printer.log("No apps found matching \"\(query)\".")
            return
        }

        let nameWidth: Int = filtered.map { $0.name.count }.max() ?? 0
        let statusLabel: String = "[installed]"
        let statusWidth: Int = statusLabel.count

        for app in filtered {
            let installed: Bool = Dependencies.detector.isInstalled(app.name)
            let namePad: String = app.name.padding(
                toLength: nameWidth + 2,
                withPad: " ",
                startingAt: 0
            )
            let status: String = installed ? statusLabel : String(repeating: " ", count: statusWidth)
            let tagline: String = app.tagline.map { "  \($0)" } ?? ""
            Printer.log("\(namePad)\(status)\(tagline)")
        }
    }
}
