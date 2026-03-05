# Suggested Commands

## Build
```bash
swift build                    # Debug build
make build                     # Release universal binary (arm64 + x86_64)
make install                   # Build and install to ~/.local/bin (BIN_DIR= to override)
```

## Test
```bash
swift test                                        # All unit tests
swift test --filter TestClass                     # Specific test class
swift test --filter TestClass/testMethod          # Single test
./test-local.sh                                   # Functional tests (live Setapp)
./test-local.sh --read-only                       # Functional tests (skip destructive XPC)
```

## Lint / Format
```bash
make lint                      # Run swiftlint and swiftformat
```

## System Utils (Darwin)
```bash
git, ls, find, grep, cat, open, sw_vers
```
