@testable import SetappCLI
import XCTest

final class SetappErrorTests: XCTestCase {
    func testAppNotFound() {
        let error = SetappError.appNotFound(name: "Foo")
        XCTAssertTrue(error.description.contains("Foo"))
        XCTAssertTrue(error.description.contains("no matching app"))
    }

    func testAppNotInstalled() {
        let error = SetappError.appNotInstalled(name: "Foo")
        XCTAssertTrue(error.description.contains("Foo"))
        XCTAssertTrue(error.description.contains("not installed"))
    }

    func testAppAlreadyInstalled() {
        let error = SetappError.appAlreadyInstalled(name: "Bar")
        XCTAssertTrue(error.description.contains("Bar"))
        XCTAssertTrue(error.description.contains("already installed"))
    }

    func testDatabaseNotFound() {
        let error = SetappError.databaseNotFound(path: "/some/path")
        XCTAssertTrue(error.description.contains("/some/path"))
        XCTAssertTrue(error.description.contains("Setapp installed"))
    }

    func testDatabaseQueryFailed() {
        let error = SetappError.databaseQueryFailed(message: "syntax error")
        XCTAssertTrue(error.description.contains("syntax error"))
    }

    func testAppListFileNotFound() {
        let error = SetappError.appListFileNotFound(path: "/AppList")
        XCTAssertTrue(error.description.contains("/AppList"))
    }

    func testAppListFileEmpty() {
        let error = SetappError.appListFileEmpty
        XCTAssertTrue(error.description.contains("empty"))
    }

    func testXPCConnectionFailed() {
        let error = SetappError.xpcConnectionFailed(message: "no service")
        XCTAssertTrue(error.description.contains("no service"))
        XCTAssertTrue(error.description.contains("Setapp running"))
    }

    func testXPCRequestTimedOut() {
        let error = SetappError.xpcRequestTimedOut(seconds: 30)
        XCTAssertTrue(error.description.contains("30"))
        XCTAssertTrue(error.description.contains("timed out"))
    }

    func testXPCRequestFailed() {
        let error = SetappError.xpcRequestFailed(message: "bad request")
        XCTAssertTrue(error.description.contains("bad request"))
    }

    func testFrameworkLoadFailed() {
        let error = SetappError.frameworkLoadFailed(message: "dlopen error")
        XCTAssertTrue(error.description.contains("dlopen error"))
    }

    func testSetappAppsDirectoryNotFound() {
        let error = SetappError.setappAppsDirectoryNotFound(path: "/Applications/Setapp")
        XCTAssertTrue(error.description.contains("/Applications/Setapp"))
    }

    func testInstallFailed() {
        let error = SetappError.installFailed(app: "Proxyman", message: "timeout")
        XCTAssertTrue(error.description.contains("Proxyman"))
        XCTAssertTrue(error.description.contains("timeout"))
    }

    func testUninstallFailed() {
        let error = SetappError.uninstallFailed(app: "Proxyman", message: "in use")
        XCTAssertTrue(error.description.contains("Proxyman"))
        XCTAssertTrue(error.description.contains("in use"))
    }

    func testGeneralError() {
        let error = SetappError.generalError(message: "something happened")
        XCTAssertEqual(error.description, "something happened")
    }

    func testErrorDescriptionMatchesDescription() {
        let errors: [SetappError] = [
            .appNotFound(name: "X"),
            .appListFileEmpty,
            .xpcRequestTimedOut(seconds: 5),
            .generalError(message: "test")
        ]
        for error in errors {
            XCTAssertEqual(error.errorDescription, error.description)
        }
    }
}
