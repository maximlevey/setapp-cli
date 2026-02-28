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
