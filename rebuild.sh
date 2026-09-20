#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DERIVED="$ROOT/build/dev"
APP="$DERIVED/Build/Products/Debug/FastReport.app"
DEST="${HOME}/Downloads/FastReport.app"

cd "$ROOT"

echo "A fechar FastReport…"
osascript -e 'tell application "FastReport" to quit' >/dev/null 2>&1 || true
sleep 0.4
killall FastReport >/dev/null 2>&1 || true
sleep 0.2

if command -v xcodegen >/dev/null; then
  xcodegen generate
fi

echo "A compilar…"
xcodebuild \
  -project FastReport.xcodeproj \
  -scheme FastReport \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  -destination 'platform=macOS' \
  build

if [[ ! -d "$APP" ]]; then
  echo "build não gerou $APP" >&2
  exit 1
fi

echo "A copiar para Descargas…"
rm -rf "$DEST"
ditto "$APP" "$DEST"

echo "A abrir…"
open "$DEST"
