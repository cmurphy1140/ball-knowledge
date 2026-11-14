#!/bin/bash
# Builds the app, puts it on a simulator, launches it and takes a screenshot.
# The simulator boots headless: Simulator.app is never opened.
#
#   ios/scripts/run.sh <simulator-udid> <screenshot-path> [launch args...]
#
# Environment:
#   BK_WAIT  seconds between launch and screenshot (default 4)
#   BK_LOG   file to receive the app's stdout, then its stderr (default: not captured)
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: run.sh <simulator-udid> <screenshot-path> [launch args...]" >&2
  exit 64
fi
UDID="$1"
SHOT="$2"
shift 2

IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="com.cmurphy.ballknowledge"
APP="$IOS_DIR/.build/DerivedData/Build/Products/Debug-iphonesimulator/BallKnowledge.app"

"$IOS_DIR/scripts/build.sh" "$UDID"

# Boots the simulator if it is off and waits until it is ready.
xcrun simctl bootstatus "$UDID" -b >/dev/null

xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

# simctl resolves --stdout and --stderr paths inside the simulator, so the app
# writes to the simulator's /tmp and the files are copied out afterwards.
LAUNCH_OPTIONS=()
if [ -n "${BK_LOG:-}" ]; then
  SIM_TMP="$(xcrun simctl getenv "$UDID" TMPDIR)"
  rm -f "${SIM_TMP}ballknowledge.stdout" "${SIM_TMP}ballknowledge.stderr"
  LAUNCH_OPTIONS+=("--stdout=/tmp/ballknowledge.stdout" "--stderr=/tmp/ballknowledge.stderr")
fi
xcrun simctl launch ${LAUNCH_OPTIONS[@]+"${LAUNCH_OPTIONS[@]}"} "$UDID" "$BUNDLE_ID" "$@"

sleep "${BK_WAIT:-4}"
mkdir -p "$(dirname "$SHOT")"
xcrun simctl io "$UDID" screenshot "$SHOT"

if [ -n "${BK_LOG:-}" ]; then
  mkdir -p "$(dirname "$BK_LOG")"
  cat "${SIM_TMP}ballknowledge.stdout" > "$BK_LOG"
  if [ -s "${SIM_TMP}ballknowledge.stderr" ]; then
    { echo "--- stderr ---"; cat "${SIM_TMP}ballknowledge.stderr"; } >> "$BK_LOG"
  fi
  echo "Wrote app output to: $BK_LOG"
fi
