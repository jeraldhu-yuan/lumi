#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Lumi"
BUNDLE_ID="com.github.jj9276489.lumi"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

cd "$ROOT_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
pkill -x "CodexSprite" >/dev/null 2>&1 || true; pkill -x "Sprite" >/dev/null 2>&1 || true

mkdir -p "$ROOT_DIR/.build"
SWIFTPM_LOG="$ROOT_DIR/.build/swiftpm-build.log"

if swift build >"$SWIFTPM_LOG" 2>&1; then
  BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"
else
  echo "SwiftPM build failed; falling back to direct swiftc build. Details: $SWIFTPM_LOG" >&2
  FALLBACK_DIR="$ROOT_DIR/.build/fallback"
  mkdir -p "$FALLBACK_DIR"
  xcrun swiftc \
    -swift-version 5 \
    -parse-as-library \
    -target arm64-apple-macosx14.0 \
    -framework AppKit \
    "$ROOT_DIR"/Sources/Lumi/*.swift \
    -o "$FALLBACK_DIR/$APP_NAME"
  BUILD_BINARY="$FALLBACK_DIR/$APP_NAME"
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

copy_asset() {
  local relative_path="$1"
  local source_path="$ROOT_DIR/$relative_path"
  local dest_path="$APP_RESOURCES/$relative_path"

  if [ -f "$source_path" ]; then
    mkdir -p "$(dirname "$dest_path")"
    cp "$source_path" "$dest_path"
  fi
}

copy_asset "Assets/ChibiAssistant/sprite-sheet.png"
copy_asset "Assets/ChibiAssistant/generated/supplemental-sheet.png"
copy_asset "Assets/ChibiAssistant/generated/extra-sheet.png"
copy_asset "Assets/ChibiAssistant/generated/standing-orientations/standing-orientations-sheet.png"
copy_asset "Assets/ChibiAssistant/generated/sitting-orientations/sitting-orientations-sheet.png"
copy_asset "Assets/ChibiAssistant/generated/sleep-wake/sleep-wake-sheet.png"
copy_asset "Assets/ChibiAssistant/generated/action-sprites/action-sprites-sheet.png"
copy_asset "Assets/ChibiAssistant/generated/expressions/expressions-sheet.png"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.4.0</string>
  <key>CFBundleVersion</key>
  <string>4</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --build|build)
    echo "Built $APP_BUNDLE"
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--build|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
