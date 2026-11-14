#!/bin/bash
# Regenerates the Xcode project, then runs the UI test target on a simulator.
# The simulator boots headless. Exits non-zero when a test fails.
#
#   ios/scripts/uitest.sh <simulator-udid>
#
# The result bundle is ios/.build/TestResults/UITests.xcresult (replaced each run).
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: uitest.sh <simulator-udid>" >&2
  exit 64
fi
UDID="$1"

IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$IOS_DIR"

RESULT=".build/TestResults/UITests.xcresult"
mkdir -p .build/TestResults
rm -rf "$RESULT"

/opt/homebrew/bin/xcodegen generate --quiet --spec project.yml

xcodebuild test \
  -project BallKnowledge.xcodeproj \
  -scheme BallKnowledge \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath .build/DerivedData \
  -resultBundlePath "$RESULT" \
  -parallel-testing-enabled NO \
  -quiet

echo "UI tests passed. Result bundle: $IOS_DIR/$RESULT"
