@testable import SetappCLI
import XCTest

class CommandTestCase: XCTestCase {
    var mockLookup: MockAppLookup {
        Dependencies.lookup as! MockAppLookup
    }

    var mockInstaller: MockAppInstaller {
        Dependencies.installer as! MockAppInstaller
    }

    var mockDetector: MockAppDetector {
        Dependencies.detector as! MockAppDetector
    }

    /// Whether any Setapp apps directory exists on this machine.
    var setappDirectoryExists: Bool {
        URL.setappAppsDirectories.contains {
            FileManager.default.directoryExists(at: $0.path)
        }
    }

    override func setUp() {
        super.setUp()
        Dependencies.lookup = MockAppLookup()
        Dependencies.installer = MockAppInstaller()
        Dependencies.detector = MockAppDetector()
        Printer.isVerbose = false
        Printer.isDebug = false
    }

    override func tearDown() {
        Dependencies.reset()
        Printer.isVerbose = false
        Printer.isDebug = false
        super.tearDown()
    }
}

// MARK: - Shared Test Doubles

/// An installer that fails install on a specific app ID, succeeds on all others.
final class FailOnInstallInstaller: AppInstaller {
    let failOnID: Int
    var installedIDs: [Int] = []
    var uninstalledIDs: [Int] = []

    init(failOnID: Int) {
        self.failOnID = failOnID
    }

    func install(appID: Int) throws {
        if appID == failOnID {
            throw SetappError.installFailed(app: "app-\(appID)", message: "simulated failure")
        }
        installedIDs.append(appID)
    }

    func uninstall(appID: Int) throws {
        uninstalledIDs.append(appID)
    }
}

/// An installer that fails uninstall on a specific app ID, succeeds on all others.
final class FailOnUninstallInstaller: AppInstaller {
    let failOnID: Int
    var installedIDs: [Int] = []
    var uninstalledIDs: [Int] = []

    init(failOnID: Int) {
        self.failOnID = failOnID
    }

    func install(appID: Int) throws {
        installedIDs.append(appID)
    }

    func uninstall(appID: Int) throws {
        if appID == failOnID {
            throw SetappError.uninstallFailed(app: "app-\(appID)", message: "simulated failure")
        }
        uninstalledIDs.append(appID)
    }
}
