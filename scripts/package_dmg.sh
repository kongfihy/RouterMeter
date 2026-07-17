#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="RouterMeter"
VOLUME_NAME="RouterMeter"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_DIR="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
STAGING_DIR="${STAGING_DIR:-$ROOT_DIR/.build/dmg-staging}"

cd "$ROOT_DIR"

DIST_DIR="$DIST_DIR" "$ROOT_DIR/scripts/package_app.sh" >/dev/null

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"

cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

rm -rf "$APP_DIR"
cp -R "$STAGING_DIR/$APP_NAME.app" "$APP_DIR"

echo "$DMG_PATH"
