#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/.." && pwd)
VERSION=$(cat "$ROOT/VERSION")
TOP="$ROOT/dist/arch"

echo "Building Arch Linux (omarchy) package..."
mkdir -p "$TOP"

cat > "$TOP/PKGBUILD" <<INNER_EOF
pkgname=omni-term-ai
pkgver=$VERSION
pkgrel=1
pkgdesc="Tmux workspace with Neovim and AI tooling"
arch=('any')
url="https://github.com/coldcanuk/omni-term-ai"
license=('GPL3')
depends=('neovim' 'tmux' 'git' 'ripgrep')
source=("\$pkgname-\$pkgver.tar.gz")
sha256sums=('SKIP')

package() {
    make -C "\$srcdir/\$pkgname-\$pkgver" DESTDIR="\$pkgdir" PREFIX=/usr install
}
INNER_EOF

echo "Arch PKGBUILD prepared in $TOP/"
if command -v makepkg >/dev/null 2>&1; then
    tar --exclude=.git --exclude=dist \
        -czf "$TOP/omni-term-ai-${VERSION}.tar.gz" \
        --transform "s,^,omni-term-ai-${VERSION}/," \
        -C "$ROOT" .
    
    cd "$TOP"
    makepkg -c -F
    cp *.pkg.tar.zst "$ROOT/dist/" 2>/dev/null || true
    echo "Arch package built in $ROOT/dist"
else
    echo "makepkg not found (not on Arch?). Arch package build skipped." >&2
fi
