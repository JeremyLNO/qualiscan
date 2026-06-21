#!/usr/bin/env bash
# Build QualiScan for the iOS Simulator, install it and launch with any args.
# Usage:
#   ./build-run.sh                       # build + launch on default device
#   ./build-run.sh -seedDemo -demoLang fr
#   ./build-run.sh -seedDemo -openDoc Invoice -demoFilter bw
#   QS_DEVICE="iPhone 16" ./build-run.sh -seedDemo
set -euo pipefail

DEV="${QS_DEVICE:-iPhone 17 Pro}"
PROJ="$(cd "$(dirname "$0")" && pwd)"
APP="$PROJ/build/Debug-iphonesimulator/QualiScan.app"

echo "▶︎ Building…"
xcodebuild -project "$PROJ/QualiScan.xcodeproj" -target QualiScan \
  -sdk iphonesimulator -configuration Debug \
  CODE_SIGNING_ALLOWED=NO SYMROOT="$PROJ/build" build \
  | grep -E "error:|warning: [A-Z]|BUILD (SUCCEEDED|FAILED)" || true

echo "▶︎ Booting $DEV…"
xcrun simctl boot "$DEV" 2>/dev/null || true
xcrun simctl bootstatus "$DEV" >/dev/null 2>&1 || true
open -a Simulator || true

echo "▶︎ Installing…"
xcrun simctl install "$DEV" "$APP"
xcrun simctl terminate "$DEV" company.lno.qualiscan 2>/dev/null || true

echo "▶︎ Launching with: $*"
xcrun simctl launch "$DEV" company.lno.qualiscan "$@"
