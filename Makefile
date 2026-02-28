BINARY := setapp-cli
FRAMEWORKS_DIR := $(HOME)/Library/Application Support/Setapp/LaunchAgents/Setapp.app/Contents/Frameworks
BUILD_DIR := $(shell swift build --configuration release --arch arm64 --arch x86_64 --show-bin-path 2>/dev/null)

.DEFAULT_GOAL := help

.PHONY: build install uninstall clean help

build:			## Build the release binary (universal)
	swift build --configuration release --arch arm64 --arch x86_64 \
		-Xlinker -rpath -Xlinker "$(FRAMEWORKS_DIR)"

install: build		## Build and install to /usr/local/bin
	install -d /usr/local/bin
	install -m 755 "$(BUILD_DIR)/$(BINARY)" "/usr/local/bin/$(BINARY)"

uninstall:		## Remove the installed binary
	rm -f "/usr/local/bin/$(BINARY)"

clean:			## Remove build artifacts
	swift package clean
	
lint:			## Run linting tools
	swiftlint --strict
	swiftformat .

help:			## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m (default: help)\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	