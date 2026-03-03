# Design: `search` Command and Graceful Degradation Hints

**Date:** 2026-03-03

---

## Overview

Two independent improvements:

1. **`search <query>` command** — search the Setapp catalogue by name, tagline, or keywords; filter by category; show installed status; hide already-installed apps.
2. **Graceful degradation hints** — append `Run \`setapp-cli diag\`` to `frameworkLoadFailed` and `xpcConnectionFailed` error messages so users know how to debug XPC failures.

---

## Feature 1: `search <query>` command

### What it does

`setapp-cli search <query>` searches the local Setapp SQLite database across three fields:
- `ZNAME` (app name)
- `ZTAGLINE` (short one-liner)
- `ZJOINEDKEYWORDS` (keyword tags)

Each result shows the app name, installation status, and tagline.

### Output format

```
setapp-cli search note

Bear          [installed]  Note-taking app powered by Markdown
GoodNotes 5               The best note-taking app for students
NotePlan      [installed]  Plan your day with a Markdown calendar
Tot                        Collect & edit bits of text
```

### Flags

| Flag | Description |
|------|-------------|
| `--category <name>` | Filter results to a single Setapp category. Valid values: `develop`, `optimize`, `work`, `create`, `ai` (maps to "Solve with AI+" in the DB). |
| `--not-installed` | Hide apps that are already installed. |

Both flags may be combined:
```
setapp-cli search note --category work --not-installed
```

### Data sources (all local SQLite)

| Column / Table | Used for |
|----------------|----------|
| `ZAPP.ZNAME` | Primary search field; display name |
| `ZAPP.ZTAGLINE` | Secondary search field; shown in output |
| `ZAPP.ZJOINEDKEYWORDS` | Tertiary search field (not displayed) |
| `ZSETAPPCATEGORY.ZNAME` | Category name lookup |
| `Z_1SETAPPCATEGORIES` | Join table: apps ↔ categories |

No network access required.

### Model change: `SetappApp`

Add an optional `tagline` field:

```swift
struct SetappApp {
    let name: String
    let bundleIdentifier: String
    let identifier: Int
    var tagline: String?   // new — nil when not needed (install, remove, list, etc.)
}
```

Existing callsites that construct `SetappApp` without tagline are unaffected (default `nil`).

### Protocol change: `AppLookup`

Add one method:

```swift
protocol AppLookup {
    func getAppByName(_ name: String) throws -> SetappApp?
    func getAvailableApps() throws -> [SetappApp]
    func searchApps(query: String, category: String?) throws -> [SetappApp]  // new
}
```

### Database query

`searchApps` uses a single SQL query with an optional `JOIN` when `category` is non-nil:

```sql
-- Without category filter:
SELECT a.ZNAME, a.ZBUNDLEIDENTIFIER, a.ZIDENTIFIER, a.ZTAGLINE
FROM ZAPP a
WHERE a.ZBUNDLEIDENTIFIER IS NOT NULL
  AND (
    LOWER(a.ZNAME) LIKE LOWER('%?%')
    OR LOWER(a.ZTAGLINE) LIKE LOWER('%?%')
    OR LOWER(a.ZJOINEDKEYWORDS) LIKE LOWER('%?%')
  )
ORDER BY LOWER(a.ZNAME)

-- With category filter (add JOIN):
... JOIN Z_1SETAPPCATEGORIES j ON j.Z_1APPLICATIONS = a.Z_PK
    JOIN ZSETAPPCATEGORY c ON c.Z_PK = j.Z_20SETAPPCATEGORIES
WHERE ... AND LOWER(c.ZNAME) LIKE LOWER('%<category>%')
```

The `ai` category slug maps to `"Solve with AI"` for the LIKE match.

### `SearchCommand` structure

```
Sources/SetappCLI/Commands/Search/SearchCommand.swift
```

```swift
struct SearchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search the Setapp catalogue."
    )

    @OptionGroup var globals: GlobalOptions

    @Argument(help: "Search query.")
    var query: String

    @Option(help: "Filter by category: develop, optimize, work, create, ai.")
    var category: String?

    @Flag(help: "Show only apps that are not installed.")
    var notInstalled: Bool = false

    mutating func run() throws { ... }
}
```

Registered in `SetappCLI.swift` alongside `ListCommand`, `CheckCommand`, etc.

### Installed status display

`[installed]` is shown using `Printer` in a dimmed/secondary color, left-aligned after the app name column. If `--not-installed` is set, any app where `Dependencies.detector.isInstalled(app.name)` returns `true` is skipped entirely.

### `MockAppLookup` update

Add a `searchApps(query:category:)` stub returning a configurable `[SetappApp]`.

---

## Feature 2: Graceful degradation hints

### Problem

When `SetappInterface.framework` fails to load (e.g. after a Setapp update changes an rpath), the user sees:

```
Error: cannot load SetappInterface: dlopen: image not found
```

There is no indication that `setapp-cli diag` exists or could help.

### Solution

Append a diagnostic hint to two `SetappError` cases in `SetappError.swift`:

| Case | Current message | Updated message |
|------|----------------|-----------------|
| `frameworkLoadFailed` | `cannot load SetappInterface: {msg}` | `cannot load SetappInterface: {msg}\nRun \`setapp-cli diag\` for details.` |
| `xpcConnectionFailed` | `XPC connection failed: {msg}\nIs Setapp running?` | `XPC connection failed: {msg}\nIs Setapp running? Run \`setapp-cli diag\` for details.` |

No other logic changes.

### Files touched

- `Sources/SetappCLI/Model/SetappError.swift`
- `Tests/SetappCLITests/Model/SetappErrorTests.swift`

---

## Files changed (summary)

| File | Change |
|------|--------|
| `Sources/SetappCLI/Model/SetappApp.swift` | Add `tagline: String?` |
| `Sources/SetappCLI/Protocols/AppLookup.swift` | Add `searchApps(query:category:)` |
| `Sources/SetappCLI/Protocols/LiveDatabase.swift` | Implement `searchApps` |
| `Sources/SetappCLI/Helpers/Database.swift` | Add `searchApps` SQL query |
| `Sources/SetappCLI/Commands/Search/SearchCommand.swift` | New file |
| `Sources/SetappCLI/Commands/SetappCLI.swift` | Register `SearchCommand` |
| `Sources/SetappCLI/Model/SetappError.swift` | Append diag hint to two cases |
| `Tests/SetappCLITests/Mocks/MockAppLookup.swift` | Add `searchApps` stub |
| `Tests/SetappCLITests/Commands/Search/SearchCommandTests.swift` | New file |
| `Tests/SetappCLITests/Model/SetappErrorTests.swift` | Update expected strings |

---

## Out of scope

- `ZMARKETINGDESCRIPTION` (full description) — too long for terminal output; deferred
- `ZVENDORNAME`, `ZPERCENTAGERATING` — could be a future `--detail` flag
- Offline catalogue (without Setapp installed) — DB path doesn't exist without Setapp
