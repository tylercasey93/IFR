#!/usr/bin/env bash
# Canonical app test invocation. Adjust SIM_OS if the installed runtimes change
# (list with: xcrun simctl list devices available).
set -euo pipefail
cd "$(dirname "$0")/.."
SIM_NAME="${SIM_NAME:-iPhone 16}"
SIM_OS="${SIM_OS:-18.3.1}"
xcodegen generate
xcodebuild -project IFRFlashCards.xcodeproj -scheme IFRFlashCards \
  -destination "platform=iOS Simulator,name=${SIM_NAME},OS=${SIM_OS}" test
