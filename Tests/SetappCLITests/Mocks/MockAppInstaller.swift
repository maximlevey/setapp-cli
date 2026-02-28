import Foundation
@testable import SetappCLI

final class MockAppInstaller: AppInstaller {
    var installedIDs: [Int] = []
    var uninstalledIDs: [Int] = []
    var installError: Error?
    var uninstallError: Error?

    func install(appID: Int) throws {
        if let installError { throw installError }
        installedIDs.append(appID)
    }

    func uninstall(appID: Int) throws {
        if let uninstallError { throw uninstallError }
        uninstalledIDs.append(appID)
    }
}
