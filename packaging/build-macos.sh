#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/.." && pwd)
VERSION=$(cat "$ROOT/VERSION")
STAGE="$ROOT/dist/macos-root"
OUTDIR="$ROOT/dist"
PKG="$OUTDIR/omni-term-ai_${VERSION}.pkg"

echo "Building macOS package..."
rm -rf "$STAGE"
mkdir -p "$OUTDIR" "$STAGE"

make -C "$ROOT" DESTDIR="$STAGE" PREFIX=/usr/local install >/dev/null

if ! command -v pkgbuild >/dev/null 2>&1; then
    echo "pkgbuild not found (are you on macOS?). macOS package build skipped." >&2
    echo "Note: macOS users can also install via Homebrew using Formula/omni-term-ai.rb" >&2
    exit 0
fi

pkgbuild --root "$STAGE" \
         --identifier com.omniterm.ai \
         --version "$VERSION" \
         "$PKG"

echo "built $PKG"
