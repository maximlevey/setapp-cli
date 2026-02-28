import Foundation
@testable import SetappCLI

final class MockAppLookup: AppLookup {
    var apps: [SetappApp] = []
    var error: Error?

    func getAppByName(_ name: String) throws -> SetappApp? {
        if let error { throw error }
        return apps.first { $0.name.lowercased() == name.lowercased() }
    }

    func getAvailableApps() throws -> [SetappApp] {
        if let error { throw error }
        return apps.sorted()
    }
}
