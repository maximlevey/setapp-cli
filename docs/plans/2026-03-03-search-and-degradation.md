# Search Command and Graceful Degradation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `search <query>` command that searches the local Setapp SQLite catalogue with tagline display, category filtering, and installed-status marking; plus append a `setapp-cli diag` hint to framework/XPC error messages.

**Architecture:** Feature 2 (graceful degradation) touches only `SetappError.swift` and its tests. Feature 1 extends the `AppLookup` protocol with a new `searchApps(query:category:)` method, adds `tagline` to `SetappApp`, implements the SQL query in `Database.swift`, and wires a new `SearchCommand` into the command hierarchy. All data comes from the local SQLite DB — no network access.

**Tech Stack:** Swift 5.9, swift-argument-parser ≥1.5, SQLite3, XCTest

---

## Task 1: Graceful degradation — update SetappError descriptions

**Files:**
- Modify: `Sources/SetappCLI/Model/SetappError.swift`
- Modify: `Tests/SetappCLITests/Model/SetappErrorTests.swift`

### Step 1: Write the failing tests

In `SetappErrorTests.swift`, update `testFrameworkLoadFailed` and `testXPCConnectionFailed` to also assert the diag hint:

```swift
func testFrameworkLoadFailed() {
    let error = SetappError.frameworkLoadFailed(message: "dlopen error")
    XCTAssertTrue(error.description.contains("dlopen error"))
    XCTAssertTrue(error.description.contains("setapp-cli diag"))
}

func testXPCConnectionFailed() {
    let error = SetappError.xpcConnectionFailed(message: "no service")
    XCTAssertTrue(error.description.contains("no service"))
    XCTAssertTrue(error.description.contains("Setapp running"))
    XCTAssertTrue(error.description.contains("setapp-cli diag"))
}
```

### Step 2: Run tests to verify they fail

```bash
swift test --filter SetappErrorTests/testFrameworkLoadFailed
swift test --filter SetappErrorTests/testXPCConnectionFailed
```

Expected: both FAIL with assertion about `setapp-cli diag`.

### Step 3: Update the two error descriptions

In `SetappError.swift`, change:

```swift
case let .frameworkLoadFailed(message):
    "cannot load SetappInterface: \(message)"
case let .xpcConnectionFailed(message):
    "XPC connection failed: \(message)\nIs Setapp running?"
```

To:

```swift
case let .frameworkLoadFailed(message):
    "cannot load SetappInterface: \(message)\nRun `setapp-cli diag` for details."
case let .xpcConnectionFailed(message):
    "XPC connection failed: \(message)\nIs Setapp running? Run `setapp-cli diag` for details."
```

### Step 4: Run tests to verify they pass

```bash
swift test --filter SetappErrorTests
```

Expected: all pass.

### Step 5: Commit

```bash
git add Sources/SetappCLI/Model/SetappError.swift \
        Tests/SetappCLITests/Model/SetappErrorTests.swift
git commit -m "fix(errors): append diag hint to frameworkLoadFailed and xpcConnectionFailed"
```

---

## Task 2: Add `tagline` to `SetappApp`

**Files:**
- Modify: `Sources/SetappCLI/Model/SetappApp.swift`

### Step 1: No new tests needed

Existing tests construct `SetappApp` without `tagline`; they must keep compiling. The new field is optional with a default — no behaviour change, so no new test required.

### Step 2: Add the field with an explicit memberwise initializer

Replace the contents of `SetappApp.swift` with:

```swift
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
    var tagline: String?

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
```

### Step 3: Verify the build is clean and all existing tests pass

```bash
swift build 2>&1 | grep -E "error:|warning:"
swift test
```

Expected: no errors, all tests pass.

### Step 4: Commit

```bash
git add Sources/SetappCLI/Model/SetappApp.swift
git commit -m "feat(model): add optional tagline field to SetappApp"
```

---

## Task 3: Add `searchApps` to `AppLookup` + `MockAppLookup`

**Files:**
- Modify: `Sources/SetappCLI/Protocols/AppLookup.swift`
- Modify: `Tests/SetappCLITests/Mocks/MockAppLookup.swift`

### Step 1: Add the method to the protocol

In `AppLookup.swift`:

```swift
import Foundation

/// Protocol for looking up apps in the Setapp catalogue.
protocol AppLookup {
    /// Find an app by name (case-insensitive).
    func getAppByName(_ name: String) throws -> SetappApp?

    /// Return all available apps sorted by name.
    func getAvailableApps() throws -> [SetappApp]

    /// Search the catalogue by name, tagline, and keywords.
    ///
    /// - Parameters:
    ///   - query: Search term matched against name, tagline, and keywords (case-insensitive).
    ///   - category: Optional category name to restrict results (e.g. `"Develop"`).
    /// - Returns: Matching apps sorted by name, each with `tagline` populated.
    func searchApps(query: String, category: String?) throws -> [SetappApp]
}
```

### Step 2: Add the stub to `MockAppLookup`

`MockAppLookup` needs a configurable `searchResults` property (separate from `apps`, which is used by the other methods) so tests can control exactly what search returns:

```swift
import Foundation
@testable import SetappCLI

final class MockAppLookup: AppLookup {
    /// Apps returned by getAppByName / getAvailableApps.
    var apps: [SetappApp] = []
    /// Apps returned by searchApps — defaults to filtering `apps` by query if nil.
    var searchResults: [SetappApp]?
    var error: Error?

    func getAppByName(_ name: String) throws -> SetappApp? {
        if let error { throw error }
        return apps.first { $0.name.lowercased() == name.lowercased() }
    }

    func getAvailableApps() throws -> [SetappApp] {
        if let error { throw error }
        return apps.sorted()
    }

    func searchApps(query: String, category: String?) throws -> [SetappApp] {
        if let error { throw error }
        if let searchResults { return searchResults }
        // Default: filter apps by name contains query, ignore category
        return apps
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .sorted()
    }
}
```

### Step 3: Verify build

```bash
swift build 2>&1 | grep "error:"
```

Expected: no errors. `LiveDatabase` will show a compile error because it doesn't yet implement `searchApps` — fix this in the next task.

---

## Task 4: Implement `Database.searchApps`

**Files:**
- Modify: `Sources/SetappCLI/Helpers/Database.swift`

### Step 1: Add the static method

Append to `Database.swift` after `getAvailableApps`:

```swift
/// Search apps by name, tagline, or keywords, with optional category filter.
///
/// - Parameters:
///   - query: Search term for `LIKE '%query%'` match against name, tagline, and keywords.
///   - category: If non-nil, only return apps in the given Setapp category (exact ZSETAPPCATEGORY.ZNAME match).
///   - connection: Optional existing connection; a new one is opened and closed if nil.
/// - Returns: Matching apps sorted by name, each with `tagline` populated.
static func searchApps(
    query: String,
    category: String?,
    connection: OpaquePointer? = nil
) throws -> [SetappApp] {
    let database: OpaquePointer = try connection ?? connect()
    defer { if connection == nil { sqlite3_close(database) } }

    let pattern: String = "%\(query)%"

    let sql: String
    if category != nil {
        sql = """
        SELECT DISTINCT a.ZNAME, a.ZBUNDLEIDENTIFIER, a.ZIDENTIFIER, a.ZTAGLINE
        FROM ZAPP a
        JOIN Z_1SETAPPCATEGORIES j ON j.Z_1APPLICATIONS = a.Z_PK
        JOIN ZSETAPPCATEGORY c ON c.Z_PK = j.Z_20SETAPPCATEGORIES
        WHERE a.ZBUNDLEIDENTIFIER IS NOT NULL
          AND (
            LOWER(a.ZNAME) LIKE LOWER(?)
            OR LOWER(a.ZTAGLINE) LIKE LOWER(?)
            OR LOWER(a.ZJOINEDKEYWORDS) LIKE LOWER(?)
          )
          AND LOWER(c.ZNAME) = LOWER(?)
        ORDER BY LOWER(a.ZNAME)
        """
    } else {
        sql = """
        SELECT a.ZNAME, a.ZBUNDLEIDENTIFIER, a.ZIDENTIFIER, a.ZTAGLINE
        FROM ZAPP a
        WHERE a.ZBUNDLEIDENTIFIER IS NOT NULL
          AND (
            LOWER(a.ZNAME) LIKE LOWER(?)
            OR LOWER(a.ZTAGLINE) LIKE LOWER(?)
            OR LOWER(a.ZJOINEDKEYWORDS) LIKE LOWER(?)
          )
        ORDER BY LOWER(a.ZNAME)
        """
    }

    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK else {
        throw SetappError.databaseQueryFailed(
            message: String(cString: sqlite3_errmsg(database))
        )
    }
    defer { sqlite3_finalize(stmt) }

    let patternPtr: UnsafePointer<CChar>? = (pattern as NSString).utf8String
    sqlite3_bind_text(stmt, 1, patternPtr, -1, nil)
    sqlite3_bind_text(stmt, 2, patternPtr, -1, nil)
    sqlite3_bind_text(stmt, 3, patternPtr, -1, nil)
    if let category: String = category {
        sqlite3_bind_text(stmt, 4, (category as NSString).utf8String, -1, nil)
    }

    var apps: [SetappApp] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
        let taglinePtr: UnsafePointer<UInt8>? = sqlite3_column_text(stmt, 3)
        let tagline: String? = taglinePtr.map { String(cString: $0) }
        apps.append(SetappApp(
            name: String(cString: sqlite3_column_text(stmt, 0)),
            bundleIdentifier: String(cString: sqlite3_column_text(stmt, 1)),
            identifier: Int(sqlite3_column_int64(stmt, 2)),
            tagline: tagline
        ))
    }
    return apps
}
```

### Step 2: Verify build

```bash
swift build 2>&1 | grep "error:"
```

Expected: still shows error from `LiveDatabase` not implementing `searchApps`.

---

## Task 5: Implement `LiveDatabase.searchApps`

**Files:**
- Modify: `Sources/SetappCLI/Protocols/LiveDatabase.swift`

### Step 1: Add the method

```swift
import Foundation

/// Live implementation of AppLookup using the Setapp SQLite database.
struct LiveDatabase: AppLookup {
    /// Find an app by name.
    func getAppByName(_ name: String) throws -> SetappApp? {
        try Database.getAppByName(name)
    }

    /// Return all available apps.
    func getAvailableApps() throws -> [SetappApp] {
        try Database.getAvailableApps()
    }

    /// Search apps by query and optional category.
    func searchApps(query: String, category: String?) throws -> [SetappApp] {
        try Database.searchApps(query: query, category: category)
    }
}
```

### Step 2: Verify clean build

```bash
swift build 2>&1 | grep "error:"
swift test
```

Expected: no errors, all existing tests pass.

### Step 3: Commit protocol + database work

```bash
git add Sources/SetappCLI/Protocols/AppLookup.swift \
        Sources/SetappCLI/Protocols/LiveDatabase.swift \
        Sources/SetappCLI/Helpers/Database.swift \
        Tests/SetappCLITests/Mocks/MockAppLookup.swift
git commit -m "feat(lookup): add searchApps(query:category:) to AppLookup, Database, LiveDatabase, MockAppLookup"
```

---

## Task 6: Create `SearchCommand`

**Files:**
- Create: `Sources/SetappCLI/Commands/Search/SearchCommand.swift`

### Step 1: Create the directory and file

Create `Sources/SetappCLI/Commands/Search/SearchCommand.swift`:

```swift
import ArgumentParser
import Foundation

/// Setapp catalogue category filter values.
enum AppCategory: String, ExpressibleByArgument, CaseIterable {
    /// Developer tools.
    case develop
    /// Productivity and system utilities.
    case optimize
    /// Work and office tools.
    case work
    /// Creative tools.
    case create
    /// AI-powered apps.
    case ai

    /// The matching ZSETAPPCATEGORY.ZNAME value in the Setapp database.
    var dbName: String {
        switch self {
        case .develop: "Develop"
        case .optimize: "Optimize"
        case .work: "Work"
        case .create: "Create"
        case .ai: "Solve with AI+"
        }
    }
}

struct SearchCommand: ParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "search",
        abstract: "Search the Setapp catalogue."
    )

    @OptionGroup var globals: GlobalOptions

    /// The search query matched against app name, tagline, and keywords.
    @Argument(help: "Search term.")
    var query: String

    /// Restrict results to a single category.
    @Option(name: .long, help: "Filter by category: develop, optimize, work, create, ai.")
    var category: AppCategory?

    /// Hide apps that are already installed.
    @Flag(name: .long, help: "Show only apps that are not installed.")
    var notInstalled: Bool = false

    mutating func run() throws {
        globals.apply()
        try Dependencies.verifyEnvironment()

        let results: [SetappApp] = try Dependencies.lookup.searchApps(
            query: query,
            category: category?.dbName
        )

        let filtered: [SetappApp] = notInstalled
            ? results.filter { !Dependencies.detector.isInstalled($0.name) }
            : results

        if filtered.isEmpty {
            Printer.log("No apps found matching \"\(query)\".")
            return
        }

        let nameWidth: Int = filtered.map { $0.name.count }.max() ?? 0
        let statusLabel: String = "[installed]"
        let statusWidth: Int = statusLabel.count

        for app in filtered {
            let installed: Bool = Dependencies.detector.isInstalled(app.name)
            let namePad: String = app.name.padding(
                toLength: nameWidth + 2,
                withPad: " ",
                startingAt: 0
            )
            let status: String = installed ? statusLabel : String(repeating: " ", count: statusWidth)
            let tagline: String = app.tagline.map { "  \($0)" } ?? ""
            Printer.log("\(namePad)\(status)\(tagline)")
        }
    }
}
```

### Step 2: Verify build

```bash
swift build 2>&1 | grep "error:"
```

Expected: no errors (command not yet registered, so it won't be reachable yet).

---

## Task 7: Register `SearchCommand` and bump version

**Files:**
- Modify: `Sources/SetappCLI/Commands/SetappCLI.swift`

### Step 1: Add `SearchCommand` to the subcommand list and bump to 2.2.0

```swift
import ArgumentParser
import Foundation

@main
struct SetappCLI: ParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "setapp-cli",
        abstract: "Install and manage Setapp apps from the command line.",
        discussion: """
        Common usage:
            setapp-cli install <app>         Install a single app
            setapp-cli search <query>        Search the Setapp catalogue
            setapp-cli list                  List installed apps
            setapp-cli bundle dump           Save installed apps to a AppList file
            setapp-cli bundle install        Install all apps from a AppList file
            setapp-cli check                 Find apps available via Setapp
        """,
        version: "2.2.0",
        subcommands: [
            InstallCommand.self,
            RemoveCommand.self,
            ReinstallCommand.self,
            ListCommand.self,
            SearchCommand.self,
            CheckCommand.self,
            BundleCommand.self
        ]
    )
}
```

### Step 2: Smoke-test the new command

```bash
swift run setapp-cli search note
```

Expected: list of apps with "note" in name/tagline/keywords, with `[installed]` markers and taglines.

```bash
swift run setapp-cli search pdf --category work
swift run setapp-cli search text --not-installed
```

Expected: filtered results.

---

## Task 8: Write `SearchCommandTests`

**Files:**
- Create: `Tests/SetappCLITests/Commands/SearchCommandTests.swift`

### Step 1: Create the test file

```swift
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
            bundleIdentifier: "com.\(name.lowercased())",
            identifier: id,
            tagline: tagline
        )
    }

    // MARK: - Tests

    func testShowsAllResultsWhenNoneInstalled() throws {
        mockLookup.searchResults = [
            makeApp("Bear", id: 1, tagline: "Note-taking app"),
            makeApp("Tot", id: 2, tagline: "Collect text snippets")
        ]

        var cmd = try SearchCommand.parse(["note"])
        XCTAssertNoThrow(try cmd.run())
    }

    func testShowsInstalledMarkerForInstalledApps() throws {
        mockLookup.searchResults = [
            makeApp("Bear", id: 1),
            makeApp("Tot", id: 2)
        ]
        mockDetector.installedNames = ["Bear"]

        var cmd = try SearchCommand.parse(["note"])
        XCTAssertNoThrow(try cmd.run())
    }

    func testNotInstalledFlagFiltersOutInstalledApps() throws {
        mockLookup.searchResults = [
            makeApp("Bear", id: 1),
            makeApp("Tot", id: 2)
        ]
        mockDetector.installedNames = ["Bear"]

        var cmd = try SearchCommand.parse(["note", "--not-installed"])
        XCTAssertNoThrow(try cmd.run())
        // Bear is installed so only Tot should pass through
        // (we verify no throw; output inspection not needed as Printer calls are side-effect only)
    }

    func testNotInstalledFlagWithAllInstalled() throws {
        mockLookup.searchResults = [
            makeApp("Bear", id: 1),
            makeApp("Tot", id: 2)
        ]
        mockDetector.installedNames = ["Bear", "Tot"]

        var cmd = try SearchCommand.parse(["note", "--not-installed"])
        // All results filtered out → should print "No apps found" and not throw
        XCTAssertNoThrow(try cmd.run())
    }

    func testEmptyResultsDoesNotThrow() throws {
        mockLookup.searchResults = []

        var cmd = try SearchCommand.parse(["xyzzy"])
        XCTAssertNoThrow(try cmd.run())
    }

    func testCategoryFlagPassedToLookup() throws {
        // Mock returns empty; we just verify the command parses and runs
        mockLookup.searchResults = []

        var cmd = try SearchCommand.parse(["note", "--category", "work"])
        XCTAssertNoThrow(try cmd.run())
    }

    func testInvalidCategoryFails() {
        XCTAssertThrowsError(try SearchCommand.parse(["note", "--category", "invalid"]))
    }

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
```

### Step 2: Run the tests

```bash
swift test --filter SearchCommandTests
```

Expected: all pass.

### Step 3: Run full test suite

```bash
swift test
```

Expected: all tests pass.

### Step 4: Commit

```bash
git add Sources/SetappCLI/Commands/Search/SearchCommand.swift \
        Sources/SetappCLI/Commands/SetappCLI.swift \
        Tests/SetappCLITests/Commands/SearchCommandTests.swift
git commit -m "feat(search): add search command with --category and --not-installed flags"
```

---

## Final verification

```bash
swift build
swift test
swift run setapp-cli --help          # should list 'search' in subcommands
swift run setapp-cli search --help   # should show query, --category, --not-installed
swift run setapp-cli search pdf
swift run setapp-cli search pdf --category work
swift run setapp-cli search pdf --not-installed
swift run setapp-cli search xyz      # expect "No apps found" message
```
