# Local Functional Tests Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** A shell script that validates the real setapp-cli binary against a live Setapp installation, with read-only tests by default and opt-in destructive E2E tests.

**Architecture:** Single `test-local.sh` script at repo root. Builds the debug binary, runs assertions against it using the real Setapp database and filesystem. Two tiers gated by `--e2e` flag.

**Tech Stack:** Bash, the compiled `setapp-cli` binary, real Setapp SQLite database and XPC service.

---

### Task 1: Create the test script skeleton with helpers

**Files:**
- Create: `test-local.sh`

**Step 1: Write the script with shebang, helpers, and pre-flight checks**

```bash
#!/usr/bin/env bash
set -euo pipefail

# --- Colors ---
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() { ((PASS++)); printf "  ${GREEN}PASS${RESET} %s\n" "$1"; }
fail() { ((FAIL++)); printf "  ${RED}FAIL${RESET} %s\n" "$1"; }
skip() { ((SKIP++)); printf "  ${YELLOW}SKIP${RESET} %s\n" "$1"; }

# --- Temp dir ---
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# --- Pre-flight ---
CLI=".build/debug/setapp-cli"
DB="$HOME/Library/Application Support/Setapp/Default/Databases/Apps.sqlite"
SETAPP_DIR="/Applications/Setapp"

printf "\n${BOLD}==> Pre-flight checks${RESET}\n"

if [[ ! -f "$DB" ]]; then
    printf "${RED}Setapp database not found at %s${RESET}\n" "$DB"
    exit 1
fi

if [[ ! -d "$SETAPP_DIR" ]]; then
    printf "${RED}Setapp apps directory not found at %s${RESET}\n" "$SETAPP_DIR"
    exit 1
fi

printf "  Database: %s\n" "$DB"
printf "  Apps dir: %s\n" "$SETAPP_DIR"

# --- Build ---
printf "\n${BOLD}==> Building${RESET}\n"
swift build 2>&1 | tail -1

if [[ ! -x "$CLI" ]]; then
    printf "${RED}Binary not found at %s${RESET}\n" "$CLI"
    exit 1
fi

printf "  Binary: %s\n\n" "$CLI"
```

**Step 2: Make it executable and test the skeleton runs**

Run: `chmod +x test-local.sh && ./test-local.sh`
Expected: Pre-flight passes, build succeeds, exits 0

**Step 3: Commit**

```bash
git add test-local.sh
git commit -m "feat: add test-local.sh skeleton with helpers and pre-flight"
```

---

### Task 2: Add Tier 1 read-only tests -- binary basics

**Files:**
- Modify: `test-local.sh`

**Step 1: Add binary basics tests after the build section**

```bash
# ============================================================
# Tier 1: Read-only tests
# ============================================================
printf "${BOLD}==> Tier 1: Read-only tests${RESET}\n"

# --- Binary basics ---
if "$CLI" --version 2>&1 | grep -q "2.0.0"; then
    pass "--version prints version"
else
    fail "--version prints version"
fi

if "$CLI" --help 2>&1 | grep -q "SUBCOMMANDS"; then
    pass "--help shows subcommands"
else
    fail "--help shows subcommands"
fi
```

**Step 2: Run and verify**

Run: `./test-local.sh`
Expected: 2 PASS

**Step 3: Commit**

```bash
git add test-local.sh
git commit -m "feat: add binary basics tests to test-local.sh"
```

---

### Task 3: Add Tier 1 tests -- list, check, dump

**Files:**
- Modify: `test-local.sh`

**Step 1: Add database and detection tests**

```bash
# --- list ---
LIST_OUT=$("$CLI" list 2>&1) || true
if echo "$LIST_OUT" | grep -q "Proxyman\|CleanMyMac\|CleanShot"; then
    pass "list shows installed apps"
else
    fail "list shows installed apps"
fi

# --- check ---
if "$CLI" check >/dev/null 2>&1; then
    pass "check exits 0"
else
    fail "check exits 0"
fi

# --- dump --list ---
DUMP_LIST=$("$CLI" dump --list 2>&1) || true
if echo "$DUMP_LIST" | grep -q "Proxyman\|CleanMyMac\|CleanShot"; then
    pass "dump --list prints installed app names"
else
    fail "dump --list prints installed app names"
fi

# --- dump --file ---
BUNDLE_TMP="$TMPDIR_TEST/test-bundle"
if "$CLI" dump --file "$BUNDLE_TMP" >/dev/null 2>&1; then
    pass "dump --file exits 0"
else
    fail "dump --file exits 0"
fi

if grep -q "^# setapp bundle" "$BUNDLE_TMP" 2>/dev/null; then
    pass "dump --file writes header comment"
else
    fail "dump --file writes header comment"
fi

if grep -qi "proxyman\|cleanmymac\|cleanshot" "$BUNDLE_TMP" 2>/dev/null; then
    pass "dump --file contains app names"
else
    fail "dump --file contains app names"
fi
```

**Step 2: Run and verify**

Run: `./test-local.sh`
Expected: 8 PASS (2 binary + 6 new)

**Step 3: Commit**

```bash
git add test-local.sh
git commit -m "feat: add list, check, dump read-only tests"
```

---

### Task 4: Add Tier 1 tests -- bundle check, bundle edit, flags, error cases

**Files:**
- Modify: `test-local.sh`

**Step 1: Add remaining read-only tests**

```bash
# --- bundle check ---
if "$CLI" bundle check --file "$BUNDLE_TMP" >/dev/null 2>&1; then
    pass "bundle check passes on freshly-dumped bundle"
else
    fail "bundle check passes on freshly-dumped bundle"
fi

# --- bundle edit (creates file) ---
EDIT_TMP="$TMPDIR_TEST/edit-test/bundle"
EDITOR=true "$CLI" bundle edit --file "$EDIT_TMP" 2>/dev/null
if grep -q "# setapp bundle" "$EDIT_TMP" 2>/dev/null; then
    pass "bundle edit creates file with header"
else
    fail "bundle edit creates file with header"
fi

# --- verbose flag ---
VERBOSE_OUT=$("$CLI" list -v 2>&1) || true
if [ ${#VERBOSE_OUT} -gt 0 ]; then
    pass "list -v produces output"
else
    fail "list -v produces output"
fi

# --- debug flag ---
DEBUG_OUT=$("$CLI" list -d 2>/dev/null) || true
DEBUG_ERR=$("$CLI" list -d 2>&1 1>/dev/null) || true
if echo "$DEBUG_ERR" | grep -q "\[debug\]"; then
    pass "list -d writes debug to stderr"
else
    fail "list -d writes debug to stderr"
fi

# --- error: install nonexistent ---
if "$CLI" install NonExistentApp123 2>/dev/null; then
    fail "install nonexistent app exits non-zero"
else
    pass "install nonexistent app exits non-zero"
fi

# --- error: remove nonexistent ---
if "$CLI" remove NonExistentApp123 2>/dev/null; then
    fail "remove nonexistent app exits non-zero"
else
    pass "remove nonexistent app exits non-zero"
fi

# --- error: bundle check missing file ---
if "$CLI" bundle check --file /nonexistent/path/bundle 2>/dev/null; then
    fail "bundle check missing file exits non-zero"
else
    pass "bundle check missing file exits non-zero"
fi
```

**Step 2: Run and verify**

Run: `./test-local.sh`
Expected: 15 PASS total

**Step 3: Commit**

```bash
git add test-local.sh
git commit -m "feat: add bundle, flags, and error case tests"
```

---

### Task 5: Add Tier 2 E2E tests with --e2e flag

**Files:**
- Modify: `test-local.sh`

**Step 1: Add E2E section gated behind --e2e flag**

After the Tier 1 summary, add:

```bash
# ============================================================
# Tier 2: End-to-end XPC tests (opt-in)
# ============================================================
E2E=false
for arg in "$@"; do
    [[ "$arg" == "--e2e" ]] && E2E=true
done

if $E2E; then
    printf "\n${BOLD}==> Tier 2: End-to-end XPC tests${RESET}\n"
    printf "${YELLOW}This will install and remove real Setapp apps (Lungo, One Switch).${RESET}\n"
    printf "Continue? [y/N] "
    read -r confirm
    if [[ "$confirm" != [yY] ]]; then
        printf "Skipped E2E tests.\n"
    else
        # Cleanup function -- remove test apps regardless of outcome
        cleanup_e2e() {
            printf "\n${BOLD}==> E2E Cleanup${RESET}\n"
            "$CLI" remove Lungo 2>/dev/null || true
            "$CLI" remove "One Switch" 2>/dev/null || true
            printf "  Cleaned up test apps.\n"
        }
        trap 'cleanup_e2e; rm -rf "$TMPDIR_TEST"' EXIT

        # --- install Lungo ---
        if "$CLI" install Lungo 2>&1 | grep -qi "installed\|already installed"; then
            pass "install Lungo succeeds"
        else
            fail "install Lungo succeeds"
        fi

        # --- verify Lungo appears in list ---
        if "$CLI" list 2>&1 | grep -q "Lungo"; then
            pass "Lungo appears in list after install"
        else
            fail "Lungo appears in list after install"
        fi

        # --- verify Lungo on disk ---
        if ls "$SETAPP_DIR"/Lungo.app >/dev/null 2>&1; then
            pass "Lungo.app exists in $SETAPP_DIR"
        else
            fail "Lungo.app exists in $SETAPP_DIR"
        fi

        # --- remove Lungo ---
        if "$CLI" remove Lungo 2>&1 | grep -qi "removed"; then
            pass "remove Lungo succeeds"
        else
            fail "remove Lungo succeeds"
        fi

        # --- verify Lungo gone from disk ---
        if ! ls "$SETAPP_DIR"/Lungo.app >/dev/null 2>&1; then
            pass "Lungo.app removed from $SETAPP_DIR"
        else
            fail "Lungo.app removed from $SETAPP_DIR"
        fi

        # --- install One Switch for reinstall test ---
        if "$CLI" install "One Switch" 2>&1 | grep -qi "installed\|already installed"; then
            pass "install One Switch succeeds"
        else
            fail "install One Switch succeeds"
        fi

        # --- reinstall One Switch ---
        if "$CLI" reinstall "One Switch" 2>&1 | grep -qi "installed"; then
            pass "reinstall One Switch succeeds"
        else
            fail "reinstall One Switch succeeds"
        fi

        # --- verify One Switch still on disk after reinstall ---
        if ls "$SETAPP_DIR"/One\ Switch.app >/dev/null 2>&1; then
            pass "One Switch.app exists after reinstall"
        else
            fail "One Switch.app exists after reinstall"
        fi

        # --- remove One Switch (cleanup) ---
        if "$CLI" remove "One Switch" 2>&1 | grep -qi "removed"; then
            pass "remove One Switch succeeds"
        else
            fail "remove One Switch succeeds"
        fi
    fi
fi
```

**Step 2: Run read-only (should not trigger E2E)**

Run: `./test-local.sh`
Expected: 15 PASS, no E2E tests run

**Step 3: Commit**

```bash
git add test-local.sh
git commit -m "feat: add Tier 2 E2E XPC tests with --e2e flag"
```

---

### Task 6: Add summary output and final polish

**Files:**
- Modify: `test-local.sh`

**Step 1: Add summary at the end of the script**

```bash
# ============================================================
# Summary
# ============================================================
printf "\n${BOLD}==> Results${RESET}\n"
printf "  ${GREEN}%d passed${RESET}" "$PASS"
if [[ $FAIL -gt 0 ]]; then
    printf ", ${RED}%d failed${RESET}" "$FAIL"
fi
if [[ $SKIP -gt 0 ]]; then
    printf ", ${YELLOW}%d skipped${RESET}" "$SKIP"
fi
printf "\n\n"

[[ $FAIL -eq 0 ]]
```

**Step 2: Run full read-only suite**

Run: `./test-local.sh`
Expected: Summary line showing "15 passed", exit 0

**Step 3: Commit**

```bash
git add test-local.sh
git commit -m "feat: add summary output to test-local.sh"
```

---

### Task 7: Add Makefile targets

**Files:**
- Modify: `Makefile`

**Step 1: Add test-local and test-e2e targets**

After the `lint` target, add:

```makefile
test-local:		## Run local functional tests (read-only)
	./test-local.sh

test-e2e:		## Run full E2E tests (installs/removes real apps)
	./test-local.sh --e2e
```

**Step 2: Verify**

Run: `make help`
Expected: test-local and test-e2e appear in help output

**Step 3: Commit**

```bash
git add Makefile
git commit -m "feat: add test-local and test-e2e Makefile targets"
```
