#!/bin/sh
# BUG-11: --deps must select pacman on Arch/Omarchy and pkg on FreeBSD.
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
fail() { echo "FAIL: $*" >&2; exit 1; }
# Pin the host to a Debian derivative. CI runs on Ubuntu (ID_LIKE=debian);
# an empty OMNI_ID_LIKE must still override it.
osr=$(mktemp)
prefix=$(mktemp -d)
trap 'rm -rf "$osr" "$prefix"' EXIT
printf 'ID=ubuntu\nID_LIKE=debian\n' >"$osr"
OMNI_OS_RELEASE=$osr
export OMNI_OS_RELEASE
# A dry run must not install. Point PREFIX at an empty dir and check it.
PREFIX=$prefix
export PREFIX
run() {
    OMNI_DEPS_DRY=1 "$ROOT/install.sh" --deps
}
out=$(OMNI_OS=Linux OMNI_DIST_ID=arch OMNI_ID_LIKE= run)
printf '%s\n' "$out" | grep -F 'DRY pacman -S --needed' >/dev/null || fail "arch did not select pacman: $out"
out=$(OMNI_OS=Linux OMNI_DIST_ID=omarchy OMNI_ID_LIKE= run)
printf '%s\n' "$out" | grep -F 'DRY pacman -S --needed' >/dev/null || fail "omarchy did not select pacman: $out"
out=$(OMNI_OS=FreeBSD run)
printf '%s\n' "$out" | grep -F 'DRY pkg install' >/dev/null || fail "freebsd did not select pkg: $out"
if OMNI_OS=Linux OMNI_DIST_ID=gentoo OMNI_ID_LIKE= OMNI_DEPS_DRY=1 "$ROOT/install.sh" --deps >/dev/null 2>&1; then
    fail "unknown distro should still fail"
fi
if [ -n "$(ls -A "$prefix")" ]; then
    fail "dry run installed files into PREFIX: $(ls -A "$prefix")"
fi
echo "deps-arch: OK"
