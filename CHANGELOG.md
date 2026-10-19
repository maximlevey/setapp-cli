---
this_file: CHANGELOG.md
---

# Changelog

## Unreleased

- Fix downloaded executables failing to load SetappInterface's sibling frameworks,
  including AgentHealthMetrics. Configure the current user's dyld fallback paths
  and relaunch before executing commands, preserving existing search paths.
- Remove the builder-specific framework rpath from the Makefile.
- Add unit and standalone integration coverage for portable framework loading,
  and verify universal release builds in CI.
- Apply the current SwiftFormat rule for multiline conditional bodies to three
  existing files so the repository's formatter check remains usable.
