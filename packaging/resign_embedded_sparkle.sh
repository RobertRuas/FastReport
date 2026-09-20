#!/bin/bash
# Re-sign Sparkle and the host app with the same identity.
# Sparkle ships already signed by another Team ID; dyld refuses to load it
# into FastReport unless both signatures match (hardened runtime / library validation).
set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" && -n "${TARGET_BUILD_DIR:-}" && -n "${WRAPPER_NAME:-}" ]]; then
  APP="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
fi
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "usage: packaging/resign_embedded_sparkle.sh FastReport.app [codesign-identity]" >&2
  exit 1
fi

if [[ "${CODE_SIGNING_ALLOWED:-YES}" == "NO" ]]; then
  echo "skipping Sparkle re-sign (CODE_SIGNING_ALLOWED=NO)"
  exit 0
fi

IDENTITY="${2:-${EXPANDED_CODE_SIGN_IDENTITY:-${CODE_SIGN_IDENTITY:--}}}"
if [[ -z "$IDENTITY" || "$IDENTITY" == "Apple Development" || "$IDENTITY" == "Apple Distribution" || "$IDENTITY" == "Developer ID Application" ]]; then
  IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-}"
fi
if [[ -z "$IDENTITY" ]]; then
  IDENTITY="-"
fi

SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
if [[ ! -d "$SPARKLE" ]]; then
  echo "Sparkle.framework missing in $APP" >&2
  exit 1
fi

TIMESTAMP_ARGS=(--timestamp=none)
if [[ "$IDENTITY" != "-" ]]; then
  TIMESTAMP_ARGS=(--timestamp)
fi

sign_item() {
  local path="$1"
  shift
  codesign --force --sign "$IDENTITY" --options runtime "${TIMESTAMP_ARGS[@]}" "$@" "$path"
}

# Innermost Sparkle helpers first. Do not use --deep: Downloader.xpc has its own entitlements.
while IFS= read -r -d '' xpc; do
  sign_item "$xpc" --preserve-metadata=entitlements
done < <(find "$SPARKLE" -name "*.xpc" -print0)

if [[ -x "$SPARKLE/Versions/B/Autoupdate" ]]; then
  sign_item "$SPARKLE/Versions/B/Autoupdate"
elif [[ -x "$SPARKLE/Versions/Current/Autoupdate" ]]; then
  sign_item "$SPARKLE/Versions/Current/Autoupdate"
fi

while IFS= read -r -d '' updater; do
  sign_item "$updater"
done < <(find "$SPARKLE/Versions" -name "Updater.app" -print0)

sign_item "$SPARKLE"

# Xcode Debug can emit unsigned helpers next to the executable (*.debug.dylib,
# __preview.dylib). Sign those first — codesign treats them as nested code of
# the main binary.
MACOS_DIR="$APP/Contents/MacOS"
MAIN_BIN="$MACOS_DIR/$(basename "$APP" .app)"
if [[ -d "$MACOS_DIR" ]]; then
  while IFS= read -r -d '' nested; do
    [[ "$nested" == "$MAIN_BIN" ]] && continue
    sign_item "$nested"
  done < <(find "$MACOS_DIR" -type f -print0)
  if [[ -f "$MAIN_BIN" ]]; then
    sign_item "$MAIN_BIN"
  fi
fi

APP_ENTITLEMENTS="${3:-${CODE_SIGN_ENTITLEMENTS:-}}"
if [[ -n "$APP_ENTITLEMENTS" && ! -f "$APP_ENTITLEMENTS" && -n "${SRCROOT:-}" ]]; then
  APP_ENTITLEMENTS="${SRCROOT}/${APP_ENTITLEMENTS}"
fi
if [[ -n "$APP_ENTITLEMENTS" && -f "$APP_ENTITLEMENTS" ]]; then
  sign_item "$APP" --entitlements "$APP_ENTITLEMENTS"
else
  sign_item "$APP" --preserve-metadata=entitlements
fi

team_of() {
  codesign -dv "$1" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2}'
}

APP_TEAM="$(team_of "$APP")"
SPARKLE_BIN="$SPARKLE/Versions/B/Sparkle"
if [[ ! -f "$SPARKLE_BIN" ]]; then
  SPARKLE_BIN="$SPARKLE/Sparkle"
fi
SPARKLE_TEAM="$(team_of "$SPARKLE_BIN")"

if [[ "$APP_TEAM" != "$SPARKLE_TEAM" ]]; then
  echo "Team ID mismatch after signing: app='$APP_TEAM' sparkle='$SPARKLE_TEAM'" >&2
  exit 1
fi

codesign --verify --verbose=2 "$APP"
echo "re-signed $APP (identity=$IDENTITY, TeamIdentifier=$APP_TEAM)"
