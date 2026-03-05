# Code Style and Conventions

## Commit Style
Conventional commits: `feat(scope):`, `fix(scope):`, `refactor(scope):`, `docs(scope):`, `style(scope):`

## Naming
- Commands: `{Action}Command`
- Protocols: `{Capability}` (e.g., `AppLookup`)
- Live implementations: `Live{Protocol}` (e.g., `LiveDatabase`)
- Mocks: `Mock{Protocol}` (e.g., `MockAppLookup`)
- Test classes mirror source structure

## SwiftLint (strict)
- Force unwrapping disallowed
- All symbols must be documented (including private/internal)

## SwiftFormat
- `--commas inline`
- `--redundanttype explicit`
- `--wrapconditions before-first`
- `--enable docComments`

## Dependency Injection
Service locator via `Dependencies` enum. Tests replace statics with mocks in `setUp()`.

```swift
enum Dependencies {
    static var lookup: AppLookup = LiveDatabase()
    static var installer: AppInstaller = LiveInstaller()
    static var detector: AppDetecting = LiveDetector()
    static var verifyEnvironment: () throws -> Void = SetappEnvironment.verify
}
```

## Command Pattern
Every command:
1. `@OptionGroup var globals: GlobalOptions` for `--verbose`/`--debug`
2. `globals.apply()` then `try Dependencies.verifyEnvironment()`
3. Uses `Dependencies.lookup/installer/detector`
4. Throws `SetappError` or `throw ExitCode(1)` for validation failures

## Key Files
- `Database.swift`: SQLite3 → `~/Library/Application Support/Setapp/Default/Databases/Apps.sqlite`, `ZAPP` table
- `AppListFile.swift`: plain-text, one app per line, `#` comments; default `~/.setapp/AppList`
- `XPCService.swift`: `dlopen` SetappInterface.framework, Mach service `com.setapp.AppsManagementService`
- `SetappDetector.swift`: scans `/Applications/Setapp` + `~/Applications/Setapp`
- `Printer.swift`: ANSI color output; colors disabled when not a TTY; debug → stderr

## Test Base Class
`CommandTestCase` in `Tests/SetappCLITests/Helpers/` — sets up mocked `Dependencies` in `setUp()`.
