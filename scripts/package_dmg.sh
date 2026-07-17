#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="RouterMeter"
VOLUME_NAME="RouterMeter"
APP_VERSION="${APP_VERSION:-0.3.0}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_DIR="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME-$APP_VERSION.dmg"
STAGING_DIR="${STAGING_DIR:-${TMPDIR:-/tmp}/RouterMeter-dmg-staging}"
STAGED_APP_DIR="$STAGING_DIR/$APP_NAME.app"

copy_clean_app() {
    local source="$1"
    local destination="$2"

    rm -rf "$destination"
    ditto --noextattr --noqtn "$source" "$destination"
    xattr -cr "$destination" 2>/dev/null || true
    codesign --force --deep --sign - "$destination" >/dev/null
    xattr -cr "$destination" 2>/dev/null || true
    codesign --verify --deep --strict "$destination"
}

cd "$ROOT_DIR"

APP_VERSION="$APP_VERSION" DIST_DIR="$DIST_DIR" "$ROOT_DIR/scripts/package_app.sh" >/dev/null

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"

copy_clean_app "$APP_DIR" "$STAGED_APP_DIR"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

copy_clean_app "$STAGED_APP_DIR" "$APP_DIR"

echo "$DMG_PATH"
