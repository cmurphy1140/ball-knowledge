#!/bin/bash
# Regenerates the Xcode project from project.yml, then builds the app for the
# iOS Simulator. Prints only warnings and errors; exits non-zero on failure.
#
#   ios/scripts/build.sh [simulator-udid]
#
# With a udid it builds for that simulator; without one, for any simulator.
# Build output goes to ios/.build/DerivedData (gitignored).
set -euo pipefail

IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$IOS_DIR"

UDID="${1:-}"
if [ -n "$UDID" ]; then
  DESTINATION="platform=iOS Simulator,id=$UDID"
else
  DESTINATION="generic/platform=iOS Simulator"
fi

/opt/homebrew/bin/xcodegen generate --quiet --spec project.yml

xcodebuild build \
  -project BallKnowledge.xcodeproj \
  -scheme BallKnowledge \
  -configuration Debug \
  -destination "$DESTINATION" \
  -derivedDataPath .build/DerivedData \
  -quiet
