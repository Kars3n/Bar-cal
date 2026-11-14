#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
RELEASE_VERSION="${1:?Usage: $0 VERSION [--export-notarized]}"
RELEASE_MODE="${2:-build}"
if [[ ! "$RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Expected a release version such as 1.0.0" >&2; exit 2
fi
case "$RELEASE_MODE" in build|--export-notarized) ;; *) echo "Unknown mode: $RELEASE_MODE" >&2; exit 2 ;; esac

DIST_ROOT="$ROOT_DIR/dist"
ARCHIVE_PATH="$DIST_ROOT/Bar-cal-$RELEASE_VERSION.xcarchive"
EXPORT_PATH="$DIST_ROOT/export-$RELEASE_VERSION"
OPTIONS_PATH="$DIST_ROOT/ExportOptions-$RELEASE_VERSION.plist"
mkdir -p "$DIST_ROOT"

if [[ "$RELEASE_MODE" == build ]]; then
  xcodebuild -project "$ROOT_DIR/Bar-cal.xcodeproj" -scheme Bar-cal \
    -configuration Release -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    -derivedDataPath "${TMPDIR:-/tmp}/barcal-release-derived" \
    ENABLE_HARDENED_RUNTIME=YES CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO archive
fi

ARCHIVE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print ApplicationProperties:CFBundleShortVersionString' "$ARCHIVE_PATH/Info.plist")"
if [[ "$ARCHIVE_VERSION" != "$RELEASE_VERSION" ]]; then
  echo "Archive version $ARCHIVE_VERSION differs from $RELEASE_VERSION" >&2; exit 1
fi

if [[ "$RELEASE_MODE" == build ]]; then
  ARCHIVE_TEAM="$(/usr/libexec/PlistBuddy -c 'Print ApplicationProperties:Team' "$ARCHIVE_PATH/Info.plist")"
  python3 - "$OPTIONS_PATH" "$ARCHIVE_TEAM" <<'PY'
import plistlib, sys
with open(sys.argv[1], "wb") as output:
    plistlib.dump({"method": "developer-id", "destination": "upload",
                  "signingStyle": "automatic", "teamID": sys.argv[2],
                  "manageAppVersionAndBuildNumber": False}, output)
PY
  xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" \
    -exportPath "$DIST_ROOT/notarization-$RELEASE_VERSION" \
    -exportOptionsPlist "$OPTIONS_PATH" -allowProvisioningUpdates
fi

# Xcode uses the signed-in developer account, including managed cloud signing.
# If Apple is still processing, rerun VERSION --export-notarized after acceptance.
xcodebuild -exportNotarizedApp -archivePath "$ARCHIVE_PATH" -exportPath "$EXPORT_PATH"
APP_PATH="$EXPORT_PATH/Bar-cal.app"
codesign --verify --deep --strict "$APP_PATH"
SIGNATURE="$(codesign -dvv "$APP_PATH" 2>&1)"
if ! [[ "$SIGNATURE" == *"Authority=Developer ID Application:"* ]]; then
  echo "A Developer ID Application signature is required for release" >&2; exit 1
fi
if [[ "$(lipo -archs "$APP_PATH/Contents/MacOS/Bar-cal")" != "arm64" ]]; then
  echo "This release package expects an Apple-silicon build" >&2; exit 1
fi
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl --assess --type execute --verbose=2 "$APP_PATH"

ZIP_NAME="Bar-cal-$RELEASE_VERSION-macOS-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$DIST_ROOT/$ZIP_NAME"
"$ROOT_DIR/script/package_dmg.sh" "$RELEASE_VERSION" "$APP_PATH"
echo "Release package: $DIST_ROOT/$ZIP_NAME"
