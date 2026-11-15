#!/bin/bash
# Builds the app for a paired iPhone, installs it and opens it.
#
#   ios/scripts/device.sh [device-udid]
#
# Without a udid it uses the first paired iPhone that is reachable (unlocked on
# the same Wi-Fi, or plugged in). Signing is automatic (team in project.yml).
# Build output goes to ios/.build/DerivedDataDevice, apart from simulator builds.
set -euo pipefail

IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$IOS_DIR"
BUNDLE_ID="com.cmurphy.ballknowledge"

DEV="${1:-}"
if [ -z "$DEV" ]; then
  DEV="$(xcrun devicectl list devices 2>/dev/null | awk '/(available \(paired\)|connected)/ && /iPhone/ { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) { print $i; exit } }')"
fi
if [ -z "$DEV" ]; then
  echo "No paired iPhone is reachable. Unlock it on the same Wi-Fi as this Mac, or plug it in." >&2
  exit 1
fi

/opt/homebrew/bin/xcodegen generate --quiet --spec project.yml
xcodebuild build \
  -project BallKnowledge.xcodeproj \
  -scheme BallKnowledge \
  -configuration Debug \
  -destination "id=$DEV" \
  -derivedDataPath .build/DerivedDataDevice \
  -allowProvisioningUpdates \
  -quiet

APP=".build/DerivedDataDevice/Build/Products/Debug-iphoneos/BallKnowledge.app"
xcrun devicectl device install app --device "$DEV" "$APP"
xcrun devicectl device process launch --device "$DEV" "$BUNDLE_ID" \
  || echo "Installed. Unlock the phone and tap Ball Knowledge to open it."
