#!/usr/bin/env bash
# A real compiler gate: Swift parse on Linux is NOT a substitute for this script.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]] || ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERROR: A complete Xcode installation on macOS is required." >&2
  exit 2
fi
python3 Scripts/generate_project.py
python3 Scripts/verify_source.py
DERIVED="$(mktemp -d "${TMPDIR:-/tmp/}/swiftlens-build.XXXXXX")"
trap 'rm -rf "$DERIVED"' EXIT
xcodebuild \
  -project SwiftLens.xcodeproj \
  -scheme SwiftLens \
  -configuration Debug \
  -sdk macosx \
  -destination 'generic/platform=macOS' \
  -arch arm64 \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  clean build
APP="$DERIVED/Build/Products/Debug/SwiftLens.app"
[[ -d "$APP" ]] || { echo "ERROR: app bundle was not produced" >&2; exit 1; }
[[ -f "$APP/Contents/Resources/Assets.car" ]] || { echo "ERROR: compiled Assets.car missing" >&2; exit 1; }
[[ -f "$APP/Contents/Resources/SwiftLensIcon.png" ]] || { echo "ERROR: SwiftLensIcon runtime fallback missing" >&2; exit 1; }
ICON_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$APP/Contents/Info.plist")"
[[ "$ICON_NAME" == "AppIcon" ]] || { echo "ERROR: CFBundleIconName = $ICON_NAME" >&2; exit 1; }
echo 'PASS full macOS arm64 AppKit build + bundled AppIcon metadata and fallback PNG' 
