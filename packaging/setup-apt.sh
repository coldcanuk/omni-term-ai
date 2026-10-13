#!/bin/sh
# Add the signed Omni Term AI apt repository and install the package.
# Debian, Ubuntu, Pop!_OS, and Ubuntu-on-WSL.
set -eu

KEY_URL=https://coldcanuk.github.io/omni-term-ai/omni-term-ai.gpg
LIST=/etc/apt/sources.list.d/omni-term-ai.list
KEYRING=/usr/share/keyrings/omni-term-ai.gpg
# RSA 4096, Omni Term AI Repository Signing, expires 2029-10-12.
EXPECT=B395A97972B309A3E4CED62AB1C4CFC685A8F91B
SOURCE_LINE="deb [signed-by=${KEYRING}] https://coldcanuk.github.io/omni-term-ai/apt /"
DRY=0

usage() {
    echo "Usage: sh packaging/setup-apt.sh [--dry-run]" >&2
    exit 1
}

while [ $# -gt 0 ]; do
    case $1 in
    --dry-run) DRY=1; shift ;;
    -h | --help) usage ;;
    *) usage ;;
    esac
done

if [ "$DRY" -eq 1 ]; then
    printf 'DRY curl -fsSL %s\n' "$KEY_URL"
    printf 'DRY gpg --show-keys expect %s\n' "$EXPECT"
    printf 'DRY install keyring %s\n' "$KEYRING"
    printf 'DRY write %s\n' "$LIST"
    printf 'DRY %s\n' "$SOURCE_LINE"
    echo "DRY apt-get update"
    echo "DRY apt-get install -y omni-term-ai"
    exit 0
fi

if ! command -v curl >/dev/null 2>&1 || ! command -v gpg >/dev/null 2>&1; then
    echo "setup-apt: install curl and gnupg first" >&2
    exit 1
fi

run() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        echo "setup-apt: need root (install sudo)" >&2
        exit 1
    fi
}

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
curl -fsSL "$KEY_URL" -o "$tmp"
got=$(gpg --batch --with-colons --show-keys "$tmp" | awk -F: '/^fpr:/ { print $10; exit }')
got=$(printf '%s' "$got" | tr -d '[:space:]')
if [ "$got" != "$EXPECT" ]; then
    echo "setup-apt: refusing to install key fingerprint '$got' (want $EXPECT)" >&2
    exit 1
fi

run mkdir -p /usr/share/keyrings
run cp "$tmp" "$KEYRING"
run chmod 644 "$KEYRING"
printf '%s\n' "$SOURCE_LINE" | run tee "$LIST" >/dev/null
run apt-get update
run apt-get install -y omni-term-ai
echo "Installed omni-term-ai from the signed apt repository"
