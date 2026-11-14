#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
RELEASE_VERSION="${1:?Usage: $0 VERSION [APP_PATH]}"
if [[ ! "$RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Expected a release version such as 1.0.0" >&2; exit 2
fi

DIST_ROOT="$ROOT_DIR/dist"
APP_PATH="${2:-$DIST_ROOT/export-$RELEASE_VERSION/Bar-cal.app}"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
if [[ "$APP_VERSION" != "$RELEASE_VERSION" ]]; then
  echo "App version $APP_VERSION differs from $RELEASE_VERSION" >&2; exit 1
fi
if [[ "$(lipo -archs "$APP_PATH/Contents/MacOS/Bar-cal")" != "arm64" ]]; then
  echo "This release package expects an Apple-silicon build" >&2; exit 1
fi
codesign --verify --deep --strict "$APP_PATH"
SIGNATURE="$(codesign -dvv "$APP_PATH" 2>&1)"
if ! [[ "$SIGNATURE" == *"Authority=Developer ID Application:"* ]]; then
  echo "A Developer ID Application signature is required for release" >&2; exit 1
fi
xcrun stapler validate "$APP_PATH"
spctl --assess --type execute --verbose=2 "$APP_PATH"

mkdir -p "$DIST_ROOT"
STAGING_PATH="$(mktemp -d "$DIST_ROOT/.dmg-stage.XXXXXX")"
MOUNT_PATH=""
cleanup() {
  if [[ -n "$MOUNT_PATH" ]]; then
    hdiutil detach "$MOUNT_PATH" -quiet || true
  fi
  rm -rf "$STAGING_PATH"
}
trap cleanup EXIT

ditto "$APP_PATH" "$STAGING_PATH/Bar-cal.app"
ln -s /Applications "$STAGING_PATH/Applications"
DMG_NAME="Bar-cal-$RELEASE_VERSION-macOS-arm64.dmg"
DMG_PATH="$DIST_ROOT/$DMG_NAME"
hdiutil create -volname Bar-cal -srcfolder "$STAGING_PATH" -fs HFS+ \
  -format UDZO -imagekey zlib-level=9 -ov "$DMG_PATH"
hdiutil verify "$DMG_PATH"

hdiutil attach "$DMG_PATH" -readonly -nobrowse -noautoopen -plist > "$STAGING_PATH/mount.plist"
MOUNT_PATH="$(python3 - "$STAGING_PATH/mount.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as source:
    entities = plistlib.load(source)['system-entities']
print(next(entity['mount-point'] for entity in entities if 'mount-point' in entity))
PY
)"
[[ "$(readlink "$MOUNT_PATH/Applications")" == /Applications ]]
codesign --verify --deep --strict "$MOUNT_PATH/Bar-cal.app"
xcrun stapler validate "$MOUNT_PATH/Bar-cal.app"
spctl --assess --type execute --verbose=2 "$MOUNT_PATH/Bar-cal.app"

(
  cd "$DIST_ROOT"
  ARTIFACTS=("$DMG_NAME")
  ZIP_NAME="Bar-cal-$RELEASE_VERSION-macOS-arm64.zip"
  if [[ -f "$ZIP_NAME" ]]; then ARTIFACTS+=("$ZIP_NAME"); fi
  shasum -a 256 "${ARTIFACTS[@]}" > SHA256SUMS.txt
  shasum -a 256 -c SHA256SUMS.txt
)
echo "Release disk image: $DMG_PATH"
