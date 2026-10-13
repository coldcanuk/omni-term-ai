#!/bin/sh
# Build an Arch/Omarchy package. Writes a PKGBUILD with a real sha256.
# Runs makepkg when it is installed; otherwise leaves the PKGBUILD and tarball.
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/.." && pwd)
VERSION=$(tr -d '[:space:]' < "$ROOT/VERSION")
TOP="$ROOT/dist/arch"
mkdir -p "$TOP" "$ROOT/dist"

tarball="$TOP/omni-term-ai-${VERSION}.tar.gz"
tar --exclude=.git --exclude=dist --exclude=.worktrees \
    -czf "$tarball" \
    --transform "s,^,omni-term-ai-${VERSION}/," \
    -C "$ROOT" .

if command -v sha256sum >/dev/null 2>&1; then
    sum=$(sha256sum "$tarball" | awk '{ print $1 }')
elif command -v shasum >/dev/null 2>&1; then
    sum=$(shasum -a 256 "$tarball" | awk '{ print $1 }')
else
    echo "build-arch: need sha256sum or shasum" >&2
    exit 1
fi

# depends() must list curl and must not hard-require python or sshfs.
# unzip is for lazy.nvim. libsecret provides secret-tool.
cat > "$TOP/PKGBUILD" <<EOF
pkgname=omni-term-ai
pkgver=${VERSION}
pkgrel=1
pkgdesc='Tmux workspace with Neovim and AI tooling'
arch=('any')
url='https://github.com/coldcanuk/omni-term-ai'
license=('GPL-3.0-only')
depends=('neovim' 'tmux' 'git' 'ripgrep' 'curl' 'unzip' 'libsecret')
optdepends=('python: bash FIM completion' 'sshfs: jumpbox remote targets' 'gnome-keyring: session keyring, including WSL')
source=("omni-term-ai-${VERSION}.tar.gz")
sha256sums=('${sum}')

package() {
    make -C "\$srcdir/\$pkgname-\$pkgver" DESTDIR="\$pkgdir" PREFIX=/usr install
}
EOF

echo "Arch PKGBUILD prepared in $TOP/ (sha256 ${sum})"
if ! command -v makepkg >/dev/null 2>&1; then
    echo "makepkg not found; Arch package was not built. Install pacman and base-devel, then re-run." >&2
    exit 0
fi

cd "$TOP"
makepkg --noconfirm --nodeps -f
found=0
for pkg in "$TOP"/omni-term-ai-*.pkg.tar.*; do
    [ -f "$pkg" ] || continue
    cp -f "$pkg" "$ROOT/dist/"
    echo "Arch package built: $ROOT/dist/$(basename "$pkg")"
    found=1
done
if [ "$found" -ne 1 ]; then
    echo "build-arch: makepkg produced no package" >&2
    exit 1
fi
