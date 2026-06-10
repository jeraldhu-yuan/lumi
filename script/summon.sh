#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Lumi"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

if [ ! -x "$APP_BINARY" ]; then
  exec "$ROOT_DIR/script/build_and_run.sh" --verify
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
/usr/bin/open -n "$APP_BUNDLE"
sleep 1
pgrep -x "$APP_NAME" >/dev/null
