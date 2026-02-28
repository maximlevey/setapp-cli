import Foundation

struct SetappApp: Equatable, Comparable {
    let name: String
    let bundleIdentifier: String
    let identifier: Int

    static func < (lhs: SetappApp, rhs: SetappApp) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
