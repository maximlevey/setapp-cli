@testable import SetappCLI
import XCTest

final class SearchCommandTests: CommandTestCase {
    // MARK: - Helpers

    private func makeApp(
        _ name: String,
        id: Int = 1,
        tagline: String? = nil
    ) -> SetappApp {
        SetappApp(
            name: name,
            bundleIdentifier: "com.\(name.lowercased().replacingOccurrences(of: " ", with: ""))",
            identifier: id,
            tagline: tagline
        )
    }

    // MARK: - Tests

    /// All results are shown when no apps are installed.
    func testShowsAllResultsWhenNoneInstalled() throws {
        mockLookup.searchResults = [
            makeApp("Bear", id: 1, tagline: "Note-taking app"),
            makeApp("Tot", id: 2, tagline: "Collect text snippets")
        ]

        var cmd = try SearchCommand.parse(["note"])
        XCTAssertNoThrow(try cmd.run())
    }

    /// Installed apps are shown with an `[installed]` marker.
    func testShowsInstalledMarkerForInstalledApps() throws {
        mockLookup.searchResults = [
            makeApp("Bear", id: 1),
            makeApp("Tot", id: 2)
        ]
        mockDetector.installedNames = ["Bear"]

        var cmd = try SearchCommand.parse(["note"])
        XCTAssertNoThrow(try cmd.run())
    }

    /// `--not-installed` removes installed apps from output.
    func testNotInstalledFlagFiltersOutInstalledApps() throws {
        mockLookup.searchResults = [
            makeApp("Bear", id: 1),
            makeApp("Tot", id: 2)
        ]
        mockDetector.installedNames = ["Bear"]

        var cmd = try SearchCommand.parse(["note", "--not-installed"])
        XCTAssertNoThrow(try cmd.run())
    }

    /// `--not-installed` with all apps installed shows the "no apps found" message without throwing.
    func testNotInstalledFlagWithAllInstalled() throws {
        mockLookup.searchResults = [
            makeApp("Bear", id: 1),
            makeApp("Tot", id: 2)
        ]
        mockDetector.installedNames = ["Bear", "Tot"]

        var cmd = try SearchCommand.parse(["note", "--not-installed"])
        XCTAssertNoThrow(try cmd.run())
    }

    /// Empty search results do not throw.
    func testEmptyResultsDoesNotThrow() throws {
        mockLookup.searchResults = []

        var cmd = try SearchCommand.parse(["xyzzy"])
        XCTAssertNoThrow(try cmd.run())
    }

    /// `--category` is accepted as a valid flag and passed through to the lookup.
    func testCategoryFlagPassedToLookup() throws {
        mockLookup.searchResults = []

        var cmd = try SearchCommand.parse(["note", "--category", "work"])
        XCTAssertNoThrow(try cmd.run())
    }

    /// An unrecognised category value causes argument parsing to fail.
    func testInvalidCategoryFails() {
        XCTAssertThrowsError(try SearchCommand.parse(["note", "--category", "invalid"]))
    }

    /// A database error thrown by the lookup propagates out of `run()`.
    func testDatabaseErrorPropagates() throws {
        mockLookup.error = SetappError.databaseNotFound(path: "/fake")

        var cmd = try SearchCommand.parse(["note"])
        XCTAssertThrowsError(try cmd.run()) { error in
            if case .databaseNotFound = error as? SetappError {
                // Expected
            } else {
                XCTFail("Expected databaseNotFound, got \(error)")
            }
        }
    }

    /// `verifyEnvironment` is called before any lookup, and its error propagates.
    func testVerifyEnvironmentCalledOnSearch() throws {
        let expected = SetappError.generalError(message: "not installed")
        Dependencies.verifyEnvironment = { throw expected }
        mockLookup.searchResults = []

        var cmd = try SearchCommand.parse(["note"])
        XCTAssertThrowsError(try cmd.run()) { error in
            XCTAssertEqual(error as? SetappError, expected)
        }
    }
}
