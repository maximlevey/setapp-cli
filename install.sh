#!/usr/bin/env bash
set -euo pipefail

BINARY="setapp-cli"
REPO="maximlevey/setapp-cli"
BIN_DIR="${1:-${PREFIX:-$HOME/.local}/bin}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

VERSION="$(
	curl -fsSL -H "Accept: application/vnd.github+json" \
		"https://api.github.com/repos/${REPO}/releases/latest" |
		sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' |
		head -n1
)" || true

if [[ -z "$VERSION" ]]; then
	echo "Error: cannot determine latest version" >&2
	exit 1
fi

ASSET="${BINARY}-${VERSION}-macos-universal.tar.gz"
URL="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET}"

echo "==> Downloading ${BINARY} ${VERSION}"

curl -fsSL "${URL}" -o "${TMP_DIR}/${ASSET}"
tar -xzf "${TMP_DIR}/${ASSET}" -C "${TMP_DIR}"

mkdir -p "${BIN_DIR}"
install -m 755 "${TMP_DIR}/${BINARY}" "${BIN_DIR}/${BINARY}"

echo "${BINARY} ${VERSION} installed to ${BIN_DIR}/${BINARY}"

if [[ ":$PATH:" != *":${BIN_DIR}:"* ]]; then
	echo "Note: ${BIN_DIR} is not in your PATH. Add it with:"
	echo "  export PATH=\"${BIN_DIR}:\$PATH\""
fi
