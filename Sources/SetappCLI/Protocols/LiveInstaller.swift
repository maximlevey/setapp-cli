import Foundation

/// Live implementation of AppInstaller using the Setapp XPC service.
struct LiveInstaller: AppInstaller {
    /// Install an app via XPC.
    func install(appID: Int) throws {
        try XPCService.install(appID: appID)
    }

    /// Uninstall an app via XPC.
    func uninstall(appID: Int) throws {
        try XPCService.uninstall(appID: appID)
    }
}
