import Foundation

/// Protocol for looking up apps in the Setapp catalogue.
protocol AppLookup {
    /// Find an app by name (case-insensitive).
    func getAppByName(_ name: String) throws -> SetappApp?

    /// Return all available apps sorted by name.
    func getAvailableApps() throws -> [SetappApp]
}
