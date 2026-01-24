SHELL := /bin/bash
.SHELLFLAGS := -e -o pipefail -c

PROJECT ?= tag.xcodeproj
ARCH ?= $(shell uname -m)
DEST ?= platform=macOS,arch=$(ARCH)

SCHEME ?= tag
INTEGRATION_SCHEME ?= tagIntegration
BUNDLE_ID ?= com.monotonic.tag

CI ?= 0
XCODEBUILD_SETTINGS ?=
ifeq ($(CI),1)
XCODEBUILD_SETTINGS += CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
endif

XCBEAUTIFY := $(shell command -v xcbeautify 2>/dev/null)
ifeq ($(NO_XCBEAUTIFY),1)
XCBEAUTIFY :=
endif

XCB := xcodebuild -project $(PROJECT) -destination '$(DEST)'
ifeq ($(strip $(XCBEAUTIFY)),)
XCB_RUN = $(XCB) $(1) $(XCODEBUILD_SETTINGS)
else
XCB_RUN = $(XCB) $(1) $(XCODEBUILD_SETTINGS) | xcbeautify
endif

.PHONY: help build clean test test-integration reset-app-data

help:
	@echo "Targets:"
	@echo "  make build              Build the app (scheme: $(SCHEME))"
	@echo "  make test               Run unit tests (scheme: $(SCHEME))"
	@echo "  make test-integration   Run integration tests (scheme: $(INTEGRATION_SCHEME))"
	@echo "  make clean              Clean derived outputs for scheme $(SCHEME)"
	@echo "  make reset-app-data     Delete app data + scheduler (quit app; requires CONFIRM=1)"
	@echo ""
	@echo "Variables:"
	@echo "  PROJECT=tag.xcodeproj"
	@echo "  SCHEME=tag"
	@echo "  INTEGRATION_SCHEME=tagIntegration"
	@echo "  BUNDLE_ID=$(BUNDLE_ID)"
	@echo "  ARCH=$$(uname -m)"
	@echo "  DEST='platform=macOS,arch=$$(uname -m)' (override if you want: platform=macOS)"
	@echo "  CI=1 (disable code signing for CI runners)"
	@echo "  NO_XCBEAUTIFY=1 (disable pretty output even if xcbeautify is installed)"
	@echo "  CONFIRM=1 (required for reset-app-data)"

build:
	@$(call XCB_RUN,build -scheme $(SCHEME))

test:
	@$(call XCB_RUN,test -scheme $(SCHEME))

test-integration:
	@$(call XCB_RUN,test -scheme $(INTEGRATION_SCHEME))

clean:
	@$(call XCB_RUN,clean -scheme $(SCHEME))

reset-app-data:
	@if [ "$(CONFIRM)" != "1" ]; then \
		echo "Refusing to delete app data without CONFIRM=1."; \
		echo "This will remove:"; \
		echo "  $$HOME/Library/Application Support/$(BUNDLE_ID)"; \
		echo "  $$HOME/Library/Logs/$(BUNDLE_ID)"; \
		echo "  $$HOME/Library/Preferences/$(BUNDLE_ID).plist"; \
		echo "  $$HOME/Library/Saved Application State/$(BUNDLE_ID).savedState"; \
		echo "  $$HOME/Library/LaunchAgents/$(BUNDLE_ID).scheduler.plist"; \
		echo ""; \
		echo "Run: make reset-app-data CONFIRM=1"; \
		exit 1; \
	fi
	@if pgrep -af "/[Tt]ag\\.app/Contents/MacOS/[Tt]ag" 2>/dev/null | grep -vq -- "--run-once"; then \
		echo "Tag appears to be running. Quit it (⌘Q) before running reset-app-data."; \
		pgrep -af "/[Tt]ag\\.app/Contents/MacOS/[Tt]ag" 2>/dev/null | grep -v -- "--run-once" || true; \
		exit 1; \
	fi
	@BUNDLE_ID="$(BUNDLE_ID)"; LABEL="$(BUNDLE_ID).scheduler"; \
	launchctl bootout "gui/$$(id -u)" "$$HOME/Library/LaunchAgents/$$LABEL.plist" 2>/dev/null || true; \
	rm -f "$$HOME/Library/LaunchAgents/$$LABEL.plist"; \
	rm -rf "$$HOME/Library/Application Support/$$BUNDLE_ID"; \
	rm -rf "$$HOME/Library/Logs/$$BUNDLE_ID"; \
	defaults delete "$$BUNDLE_ID" 2>/dev/null || true; \
	rm -f "$$HOME/Library/Preferences/$$BUNDLE_ID.plist" 2>/dev/null || true; \
	rm -rf "$$HOME/Library/Saved Application State/$$BUNDLE_ID.savedState" 2>/dev/null || true; \
	echo "Reset complete for $$BUNDLE_ID. Relaunch the app to see onboarding again."
