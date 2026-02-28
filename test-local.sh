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
