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

# --- bundle check ---
if "$CLI" bundle check --file "$BUNDLE_TMP" >/dev/null 2>&1; then
    pass "bundle check passes on freshly-dumped bundle"
else
    fail "bundle check passes on freshly-dumped bundle"
fi

# --- bundle edit (creates file) ---
EDIT_TMP="$TMPDIR_TEST/edit-test/bundle"
EDITOR=true "$CLI" bundle edit --file "$EDIT_TMP" 2>/dev/null || true
if grep -q "^# setapp bundle" "$EDIT_TMP" 2>/dev/null; then
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
        if ls "$SETAPP_DIR/One Switch.app" >/dev/null 2>&1; then
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
