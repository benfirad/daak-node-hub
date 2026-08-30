#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${DAAK_NODE_BUILD_DIR:-$HOME/Library/Caches/DAAKNodeHub/build}"
APP="$BUILD_DIR/daakLOLILE.app"
CONTENTS="$APP/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
ARCH="$(uname -m)"

if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
  echo "Desteklenmeyen Mac mimarisi: $ARCH"
  exit 1
fi

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Apple geliştirici araçları bulunamadı."
  echo "Önce şu komutu çalıştır: xcode-select --install"
  exit 1
fi

rm -rf "$APP"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

echo "daakLOLILE uygulaması hazırlanıyor…"
xcrun --sdk macosx swiftc \
  -parse-as-library \
  -O \
  -target "$ARCH-apple-macos13.0" \
  -o "$MACOS_DIR/daakLOLILE" \
  "$ROOT/Sources/daakLOLILEApp.swift" \
  -framework SwiftUI \
  -framework AppKit

cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Resources/update-daak-node.zsh" "$RESOURCES_DIR/update-daak-node.zsh"
cp "$ROOT/Resources/daak-broadcast-control.zsh" "$RESOURCES_DIR/daak-broadcast-control.zsh"
cp "$ROOT/Resources/daak-broadcast-receiver.zsh" "$RESOURCES_DIR/daak-broadcast-receiver.zsh"
chmod 755 "$RESOURCES_DIR/update-daak-node.zsh" \
  "$RESOURCES_DIR/daak-broadcast-control.zsh" \
  "$RESOURCES_DIR/daak-broadcast-receiver.zsh"

SOURCE_COMMIT="${DAAK_NODE_SOURCE_COMMIT:-}"
if [[ -z "$SOURCE_COMMIT" ]] && command -v git >/dev/null 2>&1; then
  SOURCE_COMMIT="$(git -C "$ROOT/.." rev-parse HEAD 2>/dev/null || true)"
fi
if printf '%s' "$SOURCE_COMMIT" | /usr/bin/grep -Eq '^[0-9a-f]{40}$'; then
  /usr/libexec/PlistBuddy -c "Set :DAAKSourceCommit $SOURCE_COMMIT" "$CONTENTS/Info.plist"
fi
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
xattr -cr "$APP"
codesign --verify --deep --strict "$APP"

echo ""
echo "Hazır: $APP"
echo "Açmak için: open \"$APP\""
