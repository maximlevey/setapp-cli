// this_file: Tests/SetappCLITests/Helpers/FrameworkEnvironmentTests.swift
@testable import SetappCLI
import XCTest

final class FrameworkEnvironmentTests: XCTestCase {
    private let directory = "/Users/test user/Library/Application Support/Setapp/Frameworks"

    func testPrepareWhenFrameworkMissingThenReturnsWithoutRelaunching() throws {
        let environment = ProcessInfo.processInfo.environment
        try FrameworkEnvironment.prepare(frameworkPath: "/nonexistent/SetappInterface.framework/SetappInterface")
        XCTAssertEqual(ProcessInfo.processInfo.environment, environment,
                       "Commands must remain usable when Setapp's framework is absent")
    }

    func testEnvironmentUpdatesWhenUnsetThenAddsBothSearchPaths() {
        XCTAssertEqual(FrameworkEnvironment.environmentUpdates(directory: directory, environment: [:]), [
            "DYLD_FALLBACK_FRAMEWORK_PATH": directory,
            "DYLD_FALLBACK_LIBRARY_PATH": directory
        ], "Both frameworks and sibling dylibs need a runtime search path")
    }

    func testEnvironmentUpdatesWhenPathsExistThenPreservesThem() {
        let updates = FrameworkEnvironment.environmentUpdates(directory: directory, environment: [
            "DYLD_FALLBACK_FRAMEWORK_PATH": "/custom/frameworks:/other/frameworks",
            "DYLD_FALLBACK_LIBRARY_PATH": "/custom/lib",
            "UNRELATED": "keep"
        ])
        XCTAssertEqual(updates["DYLD_FALLBACK_FRAMEWORK_PATH"], "\(directory):/custom/frameworks:/other/frameworks")
        XCTAssertEqual(updates["DYLD_FALLBACK_LIBRARY_PATH"], "\(directory):/custom/lib")
        XCTAssertNil(updates["UNRELATED"], "Unrelated environment variables must remain untouched")
    }

    func testEnvironmentUpdatesWhenAlreadyConfiguredThenDoesNotRelaunch() {
        let updates = FrameworkEnvironment.environmentUpdates(directory: directory, environment: [
            "DYLD_FALLBACK_FRAMEWORK_PATH": "\(directory):/custom/frameworks",
            "DYLD_FALLBACK_LIBRARY_PATH": "\(directory):/custom/lib"
        ])
        XCTAssertTrue(updates.isEmpty, "The restarted process must not enter a restart loop")
    }

    func testEnvironmentUpdatesWhenDirectoryIsLaterThenMovesItFirst() {
        let updates = FrameworkEnvironment.environmentUpdates(directory: directory, environment: [
            "DYLD_FALLBACK_FRAMEWORK_PATH": "/custom/frameworks:\(directory)",
            "DYLD_FALLBACK_LIBRARY_PATH": directory
        ])
        XCTAssertEqual(updates, ["DYLD_FALLBACK_FRAMEWORK_PATH": "\(directory):/custom/frameworks"],
                       "Setapp dependencies must take precedence without duplicating entries")
    }

    func testEnvironmentUpdatesWhenEmptyThenAvoidsEmptySearchEntries() {
        XCTAssertEqual(FrameworkEnvironment.environmentUpdates(directory: directory, environment: [
            "DYLD_FALLBACK_FRAMEWORK_PATH": "",
            "DYLD_FALLBACK_LIBRARY_PATH": ":"
        ]), ["DYLD_FALLBACK_FRAMEWORK_PATH": directory, "DYLD_FALLBACK_LIBRARY_PATH": directory])
    }
}
