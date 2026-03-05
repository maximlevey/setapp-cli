import Foundation

/// A Setapp app from the local catalogue.
struct SetappApp: Equatable, Comparable {
    /// Display name.
    let name: String
    /// Bundle identifier (e.g. `com.example.App-setapp`).
    let bundleIdentifier: String
    /// Setapp numeric app identifier.
    let identifier: Int
    /// Short one-line description from the catalogue.  `nil` when not queried.
    let tagline: String?

    /// Create a SetappApp.
    /// - Parameters:
    ///   - name: Display name.
    ///   - bundleIdentifier: Bundle identifier.
    ///   - identifier: Setapp numeric app identifier.
    ///   - tagline: Optional short description.
    init(
        name: String,
        bundleIdentifier: String,
        identifier: Int,
        tagline: String? = nil
    ) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.identifier = identifier
        self.tagline = tagline
    }

    static func < (lhs: SetappApp, rhs: SetappApp) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
