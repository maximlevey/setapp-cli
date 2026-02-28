import Foundation

/// Protocol for installing and uninstalling Setapp apps via XPC.
protocol AppInstaller {
    /// Install a Setapp app by its numeric ID.
    func install(appID: Int) throws

    /// Uninstall a Setapp app by its numeric ID.
    func uninstall(appID: Int) throws
}
