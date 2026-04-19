#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APPDIR="$ROOT/build/Accentuate.app"
INSTALLDIR="$HOME/Library/Input Methods"

if [ ! -d "$APPDIR" ]; then
  echo "✗ $APPDIR not found — run ./build.sh first"
  exit 1
fi

mkdir -p "$INSTALLDIR"
killall Accentuate 2>/dev/null || true
cp -r "$APPDIR" "$INSTALLDIR/"
killall SystemUIServer 2>/dev/null || true

echo "✓ Installed to: $INSTALLDIR/Accentuate.app"
echo ""
echo "Next: System Settings → Keyboard → Text Input → Edit → +"
echo "      Find 'Accentuate' in the list and add it."
