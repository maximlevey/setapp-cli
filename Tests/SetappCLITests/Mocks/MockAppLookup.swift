import Foundation
@testable import SetappCLI

final class MockAppLookup: AppLookup {
    /// Apps returned by getAppByName / getAvailableApps.
    var apps: [SetappApp] = []
    /// Apps returned by searchApps — defaults to filtering `apps` by query if nil.
    var searchResults: [SetappApp]?
    var error: Error?

    func getAppByName(_ name: String) throws -> SetappApp? {
        if let error { throw error }
        return apps.first { $0.name.lowercased() == name.lowercased() }
    }

    func getAvailableApps() throws -> [SetappApp] {
        if let error { throw error }
        return apps.sorted()
    }

    func searchApps(query: String, category: String?) throws -> [SetappApp] {
        if let error { throw error }
        if let searchResults { return searchResults }
        // Default: filter apps by name contains query, ignore category
        return apps
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .sorted()
    }
}
