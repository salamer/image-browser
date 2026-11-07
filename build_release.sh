#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Release builds require macOS with full Xcode installed (xcodebuild)." >&2
  exit 2
fi
python3 Scripts/generate_project.py
xcodebuild -project SwiftLens.xcodeproj -scheme SwiftLens -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath .build \
  CODE_SIGNING_ALLOWED=NO build
printf '\nRelease app: %s\n' "$PWD/.build/Build/Products/Release/SwiftLens.app"
