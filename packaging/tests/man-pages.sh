#!/bin/sh
# BUG-10: uninstall removes every shipped man page. Pages mention jumpbox and fim.
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
fail() { echo "FAIL: $*" >&2; exit 1; }
dest=$(mktemp -d)
make -C "$ROOT" install DESTDIR="$dest" PREFIX=/usr/local >/dev/null
man1=$dest/usr/local/share/man/man1
for p in launch-ai-workspace.1 omni-config.1 omni-secret.1 omni-exec.1; do
    [ -f "$man1/$p" ] || fail "install did not place $p"
done
make -C "$ROOT" uninstall DESTDIR="$dest" PREFIX=/usr/local >/dev/null
left=$(find "$dest" -name 'omni-*' -o -name 'launch-ai-workspace.1' | wc -l)
if [ "$left" -ne 0 ]; then
    fail "uninstall left man pages: $(find "$dest" -name 'omni-*' -o -name 'launch-ai-workspace.1')"
fi
if ! command -v man >/dev/null 2>&1; then
    fail "man is required to check page text"
fi
text=$(man -l "$ROOT/man/omni-config.1")
printf '%s\n' "$text" | grep -i jumpbox >/dev/null || fail "omni-config.1 omits jumpbox"
printf '%s\n' "$text" | grep -i fim >/dev/null || fail "omni-config.1 omits fim"
text=$(man -l "$ROOT/man/launch-ai-workspace.1")
printf '%s\n' "$text" | grep -i jumpbox >/dev/null || fail "launch page omits jumpbox"
printf '%s\n' "$text" | grep -i fim >/dev/null || fail "launch page omits fim"
rm -rf "$dest"
# Every shipped page must be in the rpm %files list, or rpmbuild fails
# with "Installed (but unpackaged) file(s) found".
spec=$ROOT/packaging/rpm/omni-term-ai.spec
for p in "$ROOT"/man/*.1; do
    b=$(basename "$p")
    grep -qF "%{_mandir}/man1/$b*" "$spec" || fail "rpm spec %files omits $b"
done
echo "man-pages: OK"
