BINARY := setapp-cli
FRAMEWORKS_DIR := $(HOME)/Library/Application Support/Setapp/LaunchAgents/Setapp.app/Contents/Frameworks
BUILD_DIR := $(shell swift build --configuration release --arch arm64 --arch x86_64 --show-bin-path 2>/dev/null)
BIN_DIR ?= $(HOME)/.local/bin

.DEFAULT_GOAL := help

.PHONY: build install uninstall clean help lint test-local test-e2e

build:			## Build the release binary (universal)
	swift build --configuration release --arch arm64 --arch x86_64 \
		-Xlinker -rpath -Xlinker "$(FRAMEWORKS_DIR)"

install: build		## Build and install to ~/.local/bin (override with BIN_DIR=)
	mkdir -p "$(BIN_DIR)"
	install -m 755 "$(BUILD_DIR)/$(BINARY)" "$(BIN_DIR)/$(BINARY)"

uninstall:		## Remove the installed binary
	rm -f "$(BIN_DIR)/$(BINARY)"

clean:			## Remove build artifacts
	swift package clean

lint:			## Run linting tools
	swiftlint --strict
	swiftformat .

test-local:		## Run local functional tests (read-only)
	./test-local.sh

test-e2e:		## Run full E2E tests (installs/removes real apps)
	./test-local.sh --e2e

help:			## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m (default: help)\n\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
