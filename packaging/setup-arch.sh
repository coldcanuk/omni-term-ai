#!/bin/sh
# Install the Arch/Omarchy package from the latest GitHub release.
# Omarchy is Arch (ID=omarchy); it uses this same pacman package.
set -eu

REPO=coldcanuk/omni-term-ai
DRY=0
VERSION=""

usage() {
    echo "Usage: sh packaging/setup-arch.sh [--dry-run] [--version X.Y.Z]" >&2
    exit 1
}

while [ $# -gt 0 ]; do
    case $1 in
    --dry-run) DRY=1; shift ;;
    --version)
        [ $# -ge 2 ] || usage
        VERSION=$2
        shift 2
        ;;
    -h | --help) usage ;;
    *) usage ;;
    esac
done

asset_for() {
    printf 'omni-term-ai-%s-1-any.pkg.tar.zst' "$1"
}

if [ "$DRY" -eq 1 ]; then
    if [ -n "$VERSION" ]; then
        name=$(asset_for "$VERSION")
        printf 'DRY curl -fL -o %s https://github.com/%s/releases/download/v%s/%s\n' \
            "$name" "$REPO" "$VERSION" "$name"
    else
        printf 'DRY curl -fsSL https://api.github.com/repos/%s/releases/latest\n' "$REPO"
        echo "DRY select browser_download_url ending in .pkg.tar.zst"
    fi
    echo "DRY pacman -U --needed <package>"
    exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "setup-arch: curl is required" >&2
    exit 1
fi
if ! command -v pacman >/dev/null 2>&1; then
    echo "setup-arch: pacman is required (Arch, Omarchy, Manjaro)" >&2
    exit 1
fi

if [ -n "$VERSION" ]; then
    name=$(asset_for "$VERSION")
    url="https://github.com/${REPO}/releases/download/v${VERSION}/${name}"
else
    api="https://api.github.com/repos/${REPO}/releases/latest"
    meta=$(curl -fsSL "$api") || {
        echo "setup-arch: could not read $api" >&2
        exit 1
    }
    url=$(printf '%s\n' "$meta" | awk -F'"' '/browser_download_url/ && $4 ~ /\.pkg\.tar\.zst$/ { print $4; exit }')
    if [ -z "$url" ]; then
        echo "setup-arch: latest release has no .pkg.tar.zst asset" >&2
        echo "Build one locally with: make arch && sudo pacman -U dist/omni-term-ai-*-any.pkg.tar.zst" >&2
        exit 1
    fi
    name=$(basename "$url")
fi

dest=${TMPDIR:-/tmp}/$name
curl -fL "$url" -o "$dest"
if [ "$(id -u)" -eq 0 ]; then
    pacman -U --needed --noconfirm "$dest"
elif command -v sudo >/dev/null 2>&1; then
    sudo pacman -U --needed --noconfirm "$dest"
else
    echo "setup-arch: need root to run pacman -U $dest" >&2
    exit 1
fi
echo "Installed $name"
