#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRCDIR="$ROOT/Accentuate/Accentuate"
STRINGSDIR="$ROOT/reference/beestation/strings"
APPDIR="$ROOT/build/Accentuate.app"
CONTENTSDIR="$APPDIR/Contents"

rm -rf "$APPDIR"
mkdir -p "$CONTENTSDIR/MacOS" "$CONTENTSDIR/Resources"

echo "▸ Compiling…"
swiftc \
  "$SRCDIR/main.swift" \
  "$SRCDIR/AppDelegate.swift" \
  "$SRCDIR/AccentEngine.swift" \
  "$SRCDIR/AccentManager.swift" \
  "$SRCDIR/AccentuateInputController.swift" \
  -framework Cocoa \
  -framework InputMethodKit \
  -target arm64-apple-macosx13.0 \
  -swift-version 5 \
  -O \
  -o "$CONTENTSDIR/MacOS/Accentuate"

echo "▸ Assembling bundle…"
# Substitute Xcode build-setting variables that Info.plist contains
sed \
  -e 's/\$(EXECUTABLE_NAME)/Accentuate/g' \
  -e 's/\$(PRODUCT_BUNDLE_IDENTIFIER)/com.accentuate.inputmethod.Accentuate/g' \
  -e 's/\$(PRODUCT_NAME)/Accentuate/g' \
  "$SRCDIR/Info.plist" > "$CONTENTSDIR/Info.plist"

cp "$STRINGSDIR"/accent_*.json "$CONTENTSDIR/Resources/"

# PkgInfo tells macOS this is an APPL bundle (required for bundle scanner recognition)
printf 'APPL????' > "$CONTENTSDIR/PkgInfo"

echo "▸ Signing (ad-hoc)…"
codesign --force --deep --sign - "$APPDIR"

echo "✓ Built: $APPDIR"
