#!/bin/sh
# BUG-11: --deps must select pacman on Arch/Omarchy and pkg on FreeBSD.
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
fail() { echo "FAIL: $*" >&2; exit 1; }
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
echo "deps-arch: OK"
