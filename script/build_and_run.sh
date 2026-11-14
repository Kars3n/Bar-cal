#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
TEMP_ROOT="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
DERIVED_DATA="$TEMP_ROOT/barcal-derived-data"
BUILD_APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/Bar-cal.app"
APP_BUNDLE="/Applications/Bar-cal.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/Bar-cal"
MODE="${1:-run}"

case "$MODE" in
  run|--debug|--logs|--telemetry|--verify) ;;
  *) echo "Usage: $0 [--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac

pkill -f "^$APP_BINARY( |$)" 2>/dev/null || true
pkill -f "^$BUILD_APP_BUNDLE/Contents/MacOS/Bar-cal( |$)" 2>/dev/null || true
xcodebuild -project "$ROOT_DIR/Bar-cal.xcodeproj" -scheme Bar-cal -configuration Debug -derivedDataPath "$DERIVED_DATA" build

# macOS 27's menu-bar host (and Bartender) needs a stable Applications path.
# Stage a fresh bundle so removed resources cannot linger across builds.
INSTALL_STAGE="$(mktemp -d /Applications/.Bar-cal-install.XXXXXX)"
cleanup_install() {
  if [[ ! -e "$APP_BUNDLE" && -d "$INSTALL_STAGE/Previous.app" ]]; then
    mv "$INSTALL_STAGE/Previous.app" "$APP_BUNDLE"
  fi
  rm -rf "$INSTALL_STAGE"
}
trap cleanup_install EXIT
ditto "$BUILD_APP_BUNDLE" "$INSTALL_STAGE/Bar-cal.app"
codesign --verify --deep --strict "$INSTALL_STAGE/Bar-cal.app"
if [[ -e "$APP_BUNDLE" ]]; then
  INSTALLED_ID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP_BUNDLE/Contents/Info.plist")"
  if [[ "$INSTALLED_ID" != "com.github.kars3n.barcal" ]]; then
    echo "Refusing to replace an unrelated app at $APP_BUNDLE" >&2
    exit 1
  fi
  mv "$APP_BUNDLE" "$INSTALL_STAGE/Previous.app"
fi
mv "$INSTALL_STAGE/Bar-cal.app" "$APP_BUNDLE"

case "$MODE" in
  run) open -n "$APP_BUNDLE" --args --show-calendar ;;
  --debug) lldb -- "$APP_BINARY" ;;
  --logs) open -n "$APP_BUNDLE" --args --show-calendar; /usr/bin/log stream --info --style compact --predicate 'process == "Bar-cal"' ;;
  --telemetry) open -n "$APP_BUNDLE" --args --show-calendar; /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.github.kars3n.barcal"' ;;
  --verify) open -n "$APP_BUNDLE" --args --show-calendar; sleep 2; pgrep -f "^$APP_BINARY( |$)" >/dev/null ;;
esac
