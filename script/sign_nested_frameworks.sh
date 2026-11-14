#!/bin/bash
set -euo pipefail

# Archive-only build phase. Sign executables from the inside out so the final
# framework signature covers the hardened-runtime helper signatures.
if [[ "${CODE_SIGNING_ALLOWED:-YES}" == "NO" ]]; then exit 0; fi
FRAMEWORK_ROOT="${BUILT_PRODUCTS_DIR:?}/${FRAMEWORKS_FOLDER_PATH:?}"
SIGNING_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-${CODE_SIGN_IDENTITY:--}}"
SIGN_OPTIONS=(--force --options runtime --sign "$SIGNING_IDENTITY")
if [[ "$SIGNING_IDENTITY" != "-" ]]; then SIGN_OPTIONS+=(--timestamp); fi

SPARKLE_APP="$FRAMEWORK_ROOT/Sparkle.framework/Versions/A/Resources/Autoupdate.app"
codesign "${SIGN_OPTIONS[@]}" "$SPARKLE_APP/Contents/MacOS/fileop"
codesign "${SIGN_OPTIONS[@]}" "$SPARKLE_APP"
codesign "${SIGN_OPTIONS[@]}" "$FRAMEWORK_ROOT/Sparkle.framework"
