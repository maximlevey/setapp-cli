# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
swift build                    # Debug build
swift test                     # Run unit tests
swift test --filter TestClass  # Run a specific test class
swift test --filter TestClass/testMethod  # Run a single test
make build                     # Release universal binary (arm64 + x86_64)
make install                   # Build and install to ~/.local/bin (BIN_DIR= to override)
make lint                      # Run swiftlint and swiftformat
./test-local.sh                # Functional tests against live Setapp installation
./test-local.sh --read-only    # Functional tests skipping destructive XPC calls
```

## Architecture

**setapp-cli** is a Swift CLI tool (macOS 12+) using `swift-argument-parser`. It manages Setapp apps: install, remove, reinstall, list, search, check, and save/restore app lists (AppList files).

### Dependency Injection

All commands access services through the `Dependencies` enum (service locator pattern), which tests replace with mocks:

```swift
enum Dependencies {
    static var lookup: AppLookup = LiveDatabase()       // app catalogue lookup
    static var installer: AppInstaller = LiveInstaller() // XPC install/uninstall
    static var detector: AppDetecting = LiveDetector()   // filesystem detection
    static var verifyEnvironment: () throws -> Void = SetappEnvironment.verify
}
```

Protocols: `AppLookup`, `AppInstaller`, `AppDetecting`. Live implementations: `LiveDatabase`, `LiveInstaller`, `LiveDetector`. Mocks: `MockAppLookup`, `MockAppInstaller`, `MockAppDetector`. `Dependencies.reset()` restores all statics to their live defaults (called in `tearDown()` in tests).

### Key Helpers

- **Database.swift**: Read-only SQLite3 access to `~/Library/Application Support/Setapp/Default/Databases/Apps.sqlite`, `ZAPP` table
- **AppListFile.swift**: Plain-text format (one app name per line, `#` comments). Default path: `~/.setapp/AppList`. Overridable via `--file` flag or `SETAPP_APP_LIST_FILE` env var
- **XPCService.swift**: Loads `SetappInterface.framework` via `dlopen()` from `~/Library/Application Support/Setapp/LaunchAgents/Setapp.app/Contents/Frameworks/`; communicates with Mach service `com.setapp.AppsManagementService`. The framework embeds no `LC_RPATH` entries, so the host binary must carry an `LC_RPATH` pointing at `Setapp.app/Contents/Frameworks/` — injected at build time via `Package.swift` (`swift build`) and `-Xlinker -rpath` in the Makefile (`make build`)
- **SetappDetector.swift**: Checks `/Applications/Setapp` and `~/Applications/Setapp` for `.app` bundles; reads `CFBundleIdentifier` from `Info.plist`
- **Printer.swift**: ANSI colored output; disables colors when not a TTY; debug output goes to stderr

### Command Pattern

Every command:
1. Has `@OptionGroup var globals: GlobalOptions` for `--verbose`/`--debug`
2. Calls `globals.apply()` then `try Dependencies.verifyEnvironment()`
3. Uses `Dependencies.lookup/installer/detector` for operations
4. Throws `SetappError` enum values; uses `throw ExitCode(1)` for validation failures

### Testing

Base class `CommandTestCase` (in `Tests/SetappCLITests/Helpers/`) sets up mocked `Dependencies` in `setUp()`. Tests mirror source structure under `Tests/SetappCLITests/Commands/`, `Helpers/`, `Model/`, etc.

## Conventions

- **Commit style**: Conventional commits — `feat(scope):`, `fix(scope):`, `refactor(scope):`, `docs(scope):`, `style(scope):`
- **Naming**: Commands as `{Action}Command`; protocols as `{Capability}`; live implementations as `Live{Protocol}`; mocks as `Mock{Protocol}`
- **SwiftLint**: Strict — force unwrapping disallowed, all symbols must be documented (including private/internal)
- **SwiftFormat**: `--commas inline`, `--redundanttype explicit`, `--wrapconditions before-first`, `--enable docComments`
- **CBridge target**: Minimal C shim for `dlopen`/`dlerror` only; all real logic is in `SetappCLI` target
