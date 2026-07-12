#!/bin/bash
# Draait de unit tests. DerivedData buiten de projectmap (SQLite disk I/O bug).
set -e
cd "$(dirname "$0")"
DD="${FLUISTER_DD:-$HOME/Library/Developer/Xcode/DerivedData/Fluister-cli}"
xcodegen generate >/dev/null
xcodebuild test \
  -project Fluister.xcodeproj \
  -scheme Fluister \
  -destination 'platform=macOS' \
  -derivedDataPath "$DD" \
  2>&1 | grep -E "Test Case .*(passed|failed)|Executed|error:|\*\* TEST|BUILD FAILED"
