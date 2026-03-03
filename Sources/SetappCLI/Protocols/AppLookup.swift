import Foundation

/// Protocol for looking up apps in the Setapp catalogue.
protocol AppLookup {
    /// Find an app by name (case-insensitive).
    func getAppByName(_ name: String) throws -> SetappApp?

    /// Return all available apps sorted by name.
    func getAvailableApps() throws -> [SetappApp]

    /// Search the catalogue by name, tagline, and keywords.
    ///
    /// - Parameters:
    ///   - query: Search term matched against name, tagline, and keywords (case-insensitive).
    ///   - category: Optional category name to restrict results (e.g. `"Develop"`).
    /// - Returns: Matching apps sorted by name, each with `tagline` populated.
    func searchApps(query: String, category: String?) throws -> [SetappApp]
}
