SHELL := /bin/bash

.DEFAULT_GOAL := help
.PHONY: help run test package package-fast clean

help:
	@printf "RecordIt commands\n"
	@printf "\n"
	@printf "  make run                       Run the macOS app with SwiftPM\n"
	@printf "  make test                      Run Swift tests\n"
	@printf "  make package                   Build app, zip, and DMG\n"
	@printf "  make package-fast              Package without running tests\n"
	@printf "  make clean                     Remove build artifacts\n"

run:
	swift run RecordIt

test:
	swift test

package:
	./scripts/package-release.sh

package-fast:
	SKIP_TESTS=1 ./scripts/package-release.sh

clean:
	swift package clean
	rm -rf dist
