# Local Functional Tests Design

## Overview

A standalone shell script (`test-local.sh`) that exercises the real compiled binary against the live Setapp installation. Two tiers: read-only (default) and full end-to-end (opt-in).

## Tier 1: Read-Only Tests (default)

Safe to run anytime, no side effects. Validates real database queries, filesystem detection, and bundle file operations.

### Tests

- **Binary basics**: `--version` exits 0 with version string, `--help` exits 0
- **list**: queries real SQLite database, prints installed apps, exits 0
- **check**: scans /Applications against real database, exits 0
- **dump --list**: detects installed Setapp apps, prints names to stdout
- **dump --file $TMPDIR/...**: writes bundle file, validates it contains app names and header comment
- **bundle check**: checks a freshly-dumped bundle file (must pass since same machine)
- **bundle edit**: creates file with header when missing (EDITOR=true)
- **Flags**: `-v` produces verbose output, `-d` produces debug output on stderr
- **Error cases**: `install NonExistentApp` exits non-zero with error, `remove NonExistentApp` exits non-zero, `bundle check --file /nonexistent` exits non-zero

## Tier 2: Full E2E Tests (opt-in via `--e2e`)

Actually installs/uninstalls real apps via XPC. Gated behind flag with confirmation prompt.

### Test Apps

- **Lungo** (ID 270): lightweight menu bar utility -- used for install/remove cycle
- **One Switch** (ID 349): lightweight utility -- used for install/reinstall/remove cycle

### Tests

- **install Lungo**: installs via XPC, verify app appears in /Applications/Setapp/
- **list after install**: confirms Lungo appears in output
- **remove Lungo**: uninstalls via XPC, verify app gone from /Applications/Setapp/
- **install One Switch**: installs via XPC
- **reinstall One Switch**: uninstalls then reinstalls
- **remove One Switch**: cleanup, verify gone

### Cleanup

Both test apps are removed at the end regardless of test outcome (trap on EXIT).

## Script Structure

- Pre-flight: verify Setapp database exists, /Applications/Setapp/ exists
- Build: `swift build`, use `.build/debug/setapp-cli`
- Temp directory for bundle files, cleaned on exit
- Color output: green pass, red fail, counts at end
- Exit 0 if all pass, 1 if any fail
- E2E flag: `--e2e` with y/n confirmation prompt before running destructive tests
