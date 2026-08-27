#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/.." && pwd)
VERSION=$(cat "$ROOT/VERSION")
STAGE="$ROOT/dist/deb-root"
OUTDIR="$ROOT/dist"
DEB="$OUTDIR/omni-term-ai_${VERSION}_all.deb"

rm -rf "$STAGE"
mkdir -p "$OUTDIR" "$STAGE/DEBIAN"

make -C "$ROOT" DESTDIR="$STAGE" PREFIX=/usr install

payload_kb=$(du -sk "$STAGE" | awk '{print $1}')
control_kb=$(du -sk "$STAGE/DEBIAN" | awk '{print $1}')
size=$((payload_kb - control_kb))
sed "s/@VERSION@/$VERSION/g" "$ROOT/packaging/deb/control" |
    awk -v size="$size" '
        /^Architecture:/ { print; print "Installed-Size: " size; next }
        { print }
    ' >"$STAGE/DEBIAN/control"

cp "$ROOT/packaging/deb/postinst" "$STAGE/DEBIAN/postinst"
chmod 755 "$STAGE/DEBIAN/postinst"

if dpkg-deb --help 2>&1 | grep -q root-owner-group; then
    dpkg-deb --root-owner-group --build "$STAGE" "$DEB"
else
    dpkg-deb --build "$STAGE" "$DEB"
fi

echo "built $DEB"
dpkg-deb -I "$DEB"
