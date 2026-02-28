#!/usr/bin/env bash
#
# Local functional tests for setapp-cli.
# Builds the debug binary and runs assertions against a live Setapp
# installation. Runs the full test suite including XPC install/remove
# by default.
#
# Usage: ./test-local.sh [--read-only]
#   --read-only  Skip destructive XPC tests (install/remove)

set -euo pipefail

# --- Constants ---
readonly GREEN=$'\033[0;32m'
readonly RED=$'\033[0;31m'
readonly YELLOW=$'\033[0;33m'
readonly BOLD=$'\033[1m'
readonly RESET=$'\033[0m'

readonly CLI='.build/debug/setapp-cli'
readonly DB="${HOME}/Library/Application Support"\
'/Setapp/Default/Databases/Apps.sqlite'
readonly SETAPP_DIR='/Applications/Setapp'

# --- Counters ---
pass_count=0
fail_count=0
skip_count=0

# Prints a PASS result and increments the counter.
pass() {
  (( pass_count++ ))
  printf '  %sPASS%s %s\n' "${GREEN}" "${RESET}" "$1"
}

# Prints a FAIL result and increments the counter.
fail() {
  (( fail_count++ ))
  printf '  %sFAIL%s %s\n' "${RED}" "${RESET}" "$1"
}

# Prints a SKIP result and increments the counter.
skip() {
  (( skip_count++ ))
  printf '  %sSKIP%s %s\n' "${YELLOW}" "${RESET}" "$1"
}

# Removes test apps installed during E2E tests.
cleanup_e2e() {
  printf '\n%s==> E2E Cleanup%s\n' "${BOLD}" "${RESET}"
  "${CLI}" remove Lungo 2>/dev/null || true
  "${CLI}" remove 'One Switch' 2>/dev/null || true
  printf '  Cleaned up test apps.\n'
}

# Verifies Setapp installation prerequisites and exits on failure.
preflight_checks() {
  printf '\n%s==> Pre-flight checks%s\n' "${BOLD}" "${RESET}"

  if [[ ! -f "${DB}" ]]; then
    printf '%sSetapp database not found at %s%s\n' \
      "${RED}" "${DB}" "${RESET}" >&2
    exit 1
  fi

  if [[ ! -d "${SETAPP_DIR}" ]]; then
    printf '%sSetapp apps directory not found at %s%s\n' \
      "${RED}" "${SETAPP_DIR}" "${RESET}" >&2
    exit 1
  fi

  printf '  Database: %s\n' "${DB}"
  printf '  Apps dir: %s\n' "${SETAPP_DIR}"
}

# Builds the debug binary and exits on failure.
build_binary() {
  printf '\n%s==> Building%s\n' "${BOLD}" "${RESET}"
  swift build 2>&1 | tail -1

  if [[ ! -x "${CLI}" ]]; then
    printf '%sBinary not found at %s%s\n' "${RED}" "${CLI}" "${RESET}" >&2
    exit 1
  fi

  printf '  Binary: %s\n\n' "${CLI}"
}

# Runs read-only tests: no installs, removals, or filesystem side effects.
run_read_only_tests() {
  local bundle_tmp="${tmpdir_test}/test-bundle"
  local edit_tmp="${tmpdir_test}/edit-test/bundle"
  local list_out dump_list verbose_out debug_err

  printf '%s==> Tier 1: Read-only tests%s\n' "${BOLD}" "${RESET}"

  # --- Binary basics ---
  if "${CLI}" --version 2>&1 | grep -q '2.0.0'; then
    pass '--version prints version'
  else
    fail '--version prints version'
  fi

  if "${CLI}" --help 2>&1 | grep -q 'SUBCOMMANDS'; then
    pass '--help shows subcommands'
  else
    fail '--help shows subcommands'
  fi

  # --- list ---
  list_out=$("${CLI}" list 2>&1) || true
  if echo "${list_out}" | grep -q 'Proxyman\|CleanMyMac\|CleanShot'; then
    pass 'list shows installed apps'
  else
    fail 'list shows installed apps'
  fi

  # --- check ---
  if "${CLI}" check >/dev/null 2>&1; then
    pass 'check exits 0'
  else
    fail 'check exits 0'
  fi

  # --- dump --list ---
  dump_list=$("${CLI}" dump --list 2>&1) || true
  if echo "${dump_list}" | grep -q 'Proxyman\|CleanMyMac\|CleanShot'; then
    pass 'dump --list prints installed app names'
  else
    fail 'dump --list prints installed app names'
  fi

  # --- dump --file ---
  if "${CLI}" dump --file "${bundle_tmp}" >/dev/null 2>&1; then
    pass 'dump --file exits 0'
  else
    fail 'dump --file exits 0'
  fi

  if grep -q '^# setapp bundle' "${bundle_tmp}" 2>/dev/null; then
    pass 'dump --file writes header comment'
  else
    fail 'dump --file writes header comment'
  fi

  if grep -qi 'proxyman\|cleanmymac\|cleanshot' "${bundle_tmp}" 2>/dev/null; then
    pass 'dump --file contains app names'
  else
    fail 'dump --file contains app names'
  fi

  # --- bundle check ---
  if "${CLI}" bundle check --file "${bundle_tmp}" >/dev/null 2>&1; then
    pass 'bundle check passes on freshly-dumped bundle'
  else
    fail 'bundle check passes on freshly-dumped bundle'
  fi

  # --- bundle edit (creates file) ---
  EDITOR=true "${CLI}" bundle edit --file "${edit_tmp}" 2>/dev/null || true
  if grep -q '^# setapp bundle' "${edit_tmp}" 2>/dev/null; then
    pass 'bundle edit creates file with header'
  else
    fail 'bundle edit creates file with header'
  fi

  # --- verbose flag ---
  verbose_out=$("${CLI}" list -v 2>&1) || true
  if [[ ${#verbose_out} -gt 0 ]]; then
    pass 'list -v produces output'
  else
    fail 'list -v produces output'
  fi

  # --- debug flag ---
  debug_err=$("${CLI}" list -d 2>&1 1>/dev/null) || true
  if echo "${debug_err}" | grep -q '\[debug\]'; then
    pass 'list -d writes debug to stderr'
  else
    fail 'list -d writes debug to stderr'
  fi

  # --- error: install nonexistent ---
  if "${CLI}" install NonExistentApp123 2>/dev/null; then
    fail 'install nonexistent app exits non-zero'
  else
    pass 'install nonexistent app exits non-zero'
  fi

  # --- error: remove nonexistent ---
  if "${CLI}" remove NonExistentApp123 2>/dev/null; then
    fail 'remove nonexistent app exits non-zero'
  else
    pass 'remove nonexistent app exits non-zero'
  fi

  # --- error: bundle check missing file ---
  if "${CLI}" bundle check --file /nonexistent/path/bundle 2>/dev/null; then
    fail 'bundle check missing file exits non-zero'
  else
    pass 'bundle check missing file exits non-zero'
  fi
}

# Runs destructive XPC tests: installs and removes real Setapp apps.
run_e2e_tests() {
  printf '\n%s==> Tier 2: End-to-end XPC tests%s\n' "${BOLD}" "${RESET}"
  trap 'cleanup_e2e; rm -rf "${tmpdir_test}"' EXIT

  # --- install Lungo ---
  if "${CLI}" install Lungo 2>&1 | grep -qi 'installed\|already installed'; then
    pass 'install Lungo succeeds'
  else
    fail 'install Lungo succeeds'
  fi

  # --- verify Lungo appears in list ---
  if "${CLI}" list 2>&1 | grep -q 'Lungo'; then
    pass 'Lungo appears in list after install'
  else
    fail 'Lungo appears in list after install'
  fi

  # --- verify Lungo on disk ---
  if ls "${SETAPP_DIR}/Lungo.app" >/dev/null 2>&1; then
    pass "Lungo.app exists in ${SETAPP_DIR}"
  else
    fail "Lungo.app exists in ${SETAPP_DIR}"
  fi

  # --- remove Lungo ---
  if "${CLI}" remove Lungo 2>&1 | grep -qi 'removed'; then
    pass 'remove Lungo succeeds'
  else
    fail 'remove Lungo succeeds'
  fi

  # --- verify Lungo gone from disk ---
  if ! ls "${SETAPP_DIR}/Lungo.app" >/dev/null 2>&1; then
    pass "Lungo.app removed from ${SETAPP_DIR}"
  else
    fail "Lungo.app removed from ${SETAPP_DIR}"
  fi

  # --- install One Switch for reinstall test ---
  if "${CLI}" install 'One Switch' 2>&1 \
      | grep -qi 'installed\|already installed'; then
    pass 'install One Switch succeeds'
  else
    fail 'install One Switch succeeds'
  fi

  # --- reinstall One Switch ---
  if "${CLI}" reinstall 'One Switch' 2>&1 | grep -qi 'installed'; then
    pass 'reinstall One Switch succeeds'
  else
    fail 'reinstall One Switch succeeds'
  fi

  # --- verify One Switch still on disk after reinstall ---
  if ls "${SETAPP_DIR}/One Switch.app" >/dev/null 2>&1; then
    pass 'One Switch.app exists after reinstall'
  else
    fail 'One Switch.app exists after reinstall'
  fi

  # --- remove One Switch (cleanup) ---
  if "${CLI}" remove 'One Switch' 2>&1 | grep -qi 'removed'; then
    pass 'remove One Switch succeeds'
  else
    fail 'remove One Switch succeeds'
  fi
}

# Prints the final pass/fail/skip summary.
print_summary() {
  printf '\n%s==> Results%s\n' "${BOLD}" "${RESET}"
  printf '  %s%d passed%s' "${GREEN}" "${pass_count}" "${RESET}"
  if [[ ${fail_count} -gt 0 ]]; then
    printf ', %s%d failed%s' "${RED}" "${fail_count}" "${RESET}"
  fi
  if [[ ${skip_count} -gt 0 ]]; then
    printf ', %s%d skipped%s' "${YELLOW}" "${skip_count}" "${RESET}"
  fi
  printf '\n\n'
}

main() {
  local read_only=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --read-only)
        read_only=true
        ;;
      *)
        printf 'Unknown flag: %s\n' "$1" >&2
        exit 1
        ;;
    esac
    shift
  done

  tmpdir_test="$(mktemp -d)"
  trap 'rm -rf "${tmpdir_test}"' EXIT

  preflight_checks
  build_binary
  run_read_only_tests

  if [[ "${read_only}" == 'false' ]]; then
    run_e2e_tests
  fi

  print_summary
  [[ ${fail_count} -eq 0 ]]
}

main "$@"
