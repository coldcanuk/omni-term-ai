#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/.." && pwd)
VERSION=$(cat "$ROOT/VERSION")

echo "Preparing OpenBSD port..."
PORTDIR="$ROOT/packaging/openbsd/sysutils/omni-term-ai"

# Ensure Makefile version is updated
sed -i.bak "s/^V =.*/V =		$VERSION/" "$PORTDIR/Makefile" 2>/dev/null || \
sed -i "s/^V =.*/V =		$VERSION/" "$PORTDIR/Makefile"
rm -f "$PORTDIR/Makefile.bak" 2>/dev/null || true

echo "OpenBSD port prepared in $PORTDIR"
echo "To build on OpenBSD:"
echo "  cp -r $PORTDIR /usr/ports/sysutils/"
echo "  cd /usr/ports/sysutils/omni-term-ai && make package"
