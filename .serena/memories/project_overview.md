# setapp-cli Project Overview

## Purpose
A Swift CLI tool (macOS 12+) for managing Setapp apps: install, remove, list, search, and save/restore app lists (AppList files).

## Tech Stack
- **Language**: Swift (macOS 12+)
- **CLI Framework**: swift-argument-parser
- **Database**: SQLite3 (read-only, via C API)
- **IPC**: XPC via `dlopen`/`SetappInterface.framework`
- **Build**: SwiftPM + Makefile
- **Linting**: SwiftLint (strict), SwiftFormat

## Targets
- `SetappCLI` — main CLI target
- `CBridge` — minimal C shim for `dlopen`/`dlerror` only

## Source Structure
```
Sources/
  SetappCLI/
    Commands/         # One subdir per command (Install, Remove, List, Search, Bundle, Check, Reinstall)
    Protocols/        # AppLookup, AppInstaller, AppDetecting + Live implementations + Dependencies
    Helpers/          # Database, AppListFile, XPCService, SetappDetector, Printer, SetappEnvironment
    Model/            # SetappApp, SetappError
    Extensions/       # FileManager+Extension, URL+Extension
  CBridge/            # CBridge.c + include/CBridge.h
Tests/
  SetappCLITests/
    Commands/         # Per-command test files
    Mocks/            # MockAppLookup, MockAppInstaller, MockAppDetector
    Helpers/          # CommandTestCase (base class), TempDirectory, etc.
    Model/            # SetappApp/SetappError tests
    Extensions/       # Extension tests
```
