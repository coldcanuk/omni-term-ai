#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

make -C "$ROOT" DESTDIR="$STAGE" PREFIX=/usr install

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

for f in \
    usr/bin/launch-ai-workspace \
    usr/bin/omni-exec \
    usr/bin/omni-secret \
    usr/bin/omni-config \
    usr/bin/tmux-toggle-scratch \
    usr/share/omni-term-ai/lib/omni.sh \
    usr/share/omni-term-ai/tmux.conf \
    usr/share/omni-term-ai/nvim-config/init.lua \
    usr/share/applications/ai-workspace.desktop \
    usr/share/icons/hicolor/scalable/apps/ai-workspace.svg \
    usr/share/man/man1/launch-ai-workspace.1 \
    usr/share/man/man1/omni-config.1 \
    usr/share/doc/omni-term-ai/README.md \
    usr/share/doc/omni-term-ai/LICENSE; do
    [ -e "$STAGE/$f" ] || fail "missing $f"
done

for f in usr/bin/launch-ai-workspace usr/bin/omni-exec usr/bin/omni-secret usr/bin/omni-config usr/bin/tmux-toggle-scratch; do
    [ -x "$STAGE/$f" ] || fail "not executable: $f"
done

grep -q '^Exec=launch-ai-workspace$' "$STAGE/usr/share/applications/ai-workspace.desktop" \
    || fail "desktop Exec must be launch-ai-workspace"
grep -q '/usr/share/omni-term-ai' "$STAGE/usr/bin/launch-ai-workspace" \
    || fail "launcher must embed PREFIX share path"
if grep -R '/opt/repo' "$STAGE" >/dev/null 2>&1; then
    grep -R '/opt/repo' "$STAGE" || true
    fail "staged tree contains hardcoded /opt/repo"
fi
if grep -R '/home/chuck' "$STAGE" >/dev/null 2>&1; then
    grep -R '/home/chuck' "$STAGE" || true
    fail "staged tree contains hardcoded /home/chuck"
fi

# Source-tree scripts must parse.
for s in launch-ai-workspace omni-exec.sh omni-secret omni-config tmux-toggle-scratch install.sh \
    packaging/build-deb.sh packaging/build-rpm.sh packaging/tests/verify-install.sh; do
    sh -n "$ROOT/$s" || fail "sh -n $s"
done

OMNI_TERM_AI_HOME="$ROOT" "$STAGE/usr/bin/omni-secret" backend >/dev/null \
    || fail "omni-secret backend"

echo "verify-install: OK ($STAGE layout checked)"
