# Task Completion Checklist

When a task is complete, always:

1. **Build**: `swift build` — ensure no compile errors
2. **Test**: `swift test` — all unit tests must pass
3. **Lint/Format**: `make lint` — SwiftLint + SwiftFormat clean
4. **Document**: All new/modified symbols must have doc comments (SwiftLint enforces this)
5. **CLAUDE.md**: Update if architecture, commands, or conventions changed
6. **Commit**: Use conventional commit format `type(scope): message`
   - Never include `Co-Authored-By: Claude` in commits
   - Use `op plugin run -- gh` instead of `gh` for GitHub CLI
