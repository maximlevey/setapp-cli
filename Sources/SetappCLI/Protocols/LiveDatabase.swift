import Foundation

/// Live implementation of AppLookup using the Setapp SQLite database.
struct LiveDatabase: AppLookup {
    /// Find an app by name.
    func getAppByName(_ name: String) throws -> SetappApp? {
        try Database.getAppByName(name)
    }

    /// Return all available apps.
    func getAvailableApps() throws -> [SetappApp] {
        try Database.getAvailableApps()
    }
}
