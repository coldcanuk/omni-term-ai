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
    usr/share/omni-term-ai/lib/omni-bash.sh \
    usr/share/omni-term-ai/lib/deepseek-completion.bash \
    usr/share/omni-term-ai/lib/boot.sh \
    usr/share/omni-term-ai/tmux.conf \
    usr/share/omni-term-ai/nvim-config/init.lua \
    usr/share/omni-term-ai/nvim-config/lua/omni_fim.lua \
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

grep -q '^Exec=/usr/bin/launch-ai-workspace$' "$STAGE/usr/share/applications/ai-workspace.desktop" \
    || fail "desktop Exec must be /usr/bin/launch-ai-workspace"
grep -q '/usr/share/omni-term-ai' "$STAGE/usr/bin/launch-ai-workspace" \
    || fail "launcher must embed PREFIX share path"
# Dropping these from the Makefile must fail make test. The installed
# copies must also have had @OMNI_HOME@ rewritten.
for f in usr/share/omni-term-ai/lib/omni-bash.sh usr/share/omni-term-ai/lib/boot.sh; do
    if grep -q '@OMNI_HOME@' "$STAGE/$f"; then
        fail "$f still contains @OMNI_HOME@"
    fi
    grep -q '/usr/share/omni-term-ai' "$STAGE/$f" || fail "$f missing installed home"
done
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
    lib/omni.sh lib/omni-bash.sh lib/deepseek-completion.bash lib/boot.sh packaging/build-deb.sh packaging/build-rpm.sh packaging/tests/verify-install.sh \
    packaging/tests/config-roundtrip.sh packaging/tests/jumpbox-args.sh packaging/tests/empty-secrets.sh \
    packaging/tests/azure-env.sh packaging/tests/fim-provider.sh packaging/tests/gh-pages-guard.sh packaging/tests/deps-arch.sh packaging/tests/bash-fim.sh packaging/tests/fim-stale.sh packaging/tests/man-pages.sh packaging/tests/agents-path.sh \
    packaging/tests/shell-integration.sh packaging/tests/nvim-startup.sh \
    packaging/build-repo.sh packaging/tests/repo-client.sh packaging/tests/repo-signing.sh \
    packaging/tests/package-deps.sh; do
    sh -n "$ROOT/$s" || fail "sh -n $s"
done

sh "$ROOT/packaging/tests/config-roundtrip.sh"
sh "$ROOT/packaging/tests/jumpbox-args.sh"
sh "$ROOT/packaging/tests/empty-secrets.sh"
sh "$ROOT/packaging/tests/azure-env.sh"
sh "$ROOT/packaging/tests/gh-pages-guard.sh"
sh "$ROOT/packaging/tests/deps-arch.sh"
sh "$ROOT/packaging/tests/fim-provider.sh"
bash "$ROOT/packaging/tests/bash-fim.sh"
sh "$ROOT/packaging/tests/fim-stale.sh"
sh "$ROOT/packaging/tests/man-pages.sh"
sh "$ROOT/packaging/tests/agents-path.sh"
sh "$ROOT/packaging/tests/shell-integration.sh"
rc=0
sh "$ROOT/packaging/tests/nvim-startup.sh" || rc=$?
[ "$rc" -eq 0 ] || [ "$rc" -eq 77 ] || fail "nvim-startup.sh"
sh "$ROOT/packaging/tests/repo-signing.sh"
sh "$ROOT/packaging/tests/package-deps.sh"

# Non-network parse of the editor Lua. Skip if luac is absent.
if command -v luac >/dev/null 2>&1; then
    luac -p "$ROOT/nvim-config/lua/omni_fim.lua" || fail "luac omni_fim.lua"
    luac -p "$ROOT/nvim-config/init.lua" || fail "luac init.lua"
else
    echo "luac: SKIP (not installed)"
fi

# Optional. CI installs the binary. -S error ignores the
# CDPATH= cd idiom, which this linter misreads as SC1007.
if command -v shellcheck >/dev/null 2>&1; then
    for s in lib/omni.sh lib/boot.sh launch-ai-workspace omni-secret omni-config \
        tmux-toggle-scratch install.sh packaging/build-deb.sh packaging/build-rpm.sh \
        packaging/build-repo.sh packaging/tests/verify-install.sh \
        packaging/tests/config-roundtrip.sh packaging/tests/jumpbox-args.sh \
        packaging/tests/empty-secrets.sh packaging/tests/azure-env.sh \
        packaging/tests/fim-provider.sh packaging/tests/gh-pages-guard.sh \
        packaging/tests/deps-arch.sh packaging/tests/fim-stale.sh \
        packaging/tests/man-pages.sh packaging/tests/agents-path.sh \
        packaging/tests/nvim-startup.sh packaging/tests/repo-client.sh \
        packaging/tests/repo-signing.sh packaging/tests/shell-integration.sh \
        packaging/tests/package-deps.sh; do
        shellcheck -S error -s sh "$ROOT/$s" || fail "shellcheck $s"
    done
    for s in lib/omni-bash.sh lib/deepseek-completion.bash packaging/tests/bash-fim.sh; do
        shellcheck -S error -s bash "$ROOT/$s" || fail "shellcheck $s"
    done
else
    echo "shellcheck: SKIP (not installed)"
fi

# pty-driven tests. Need python3; exit 77 means skipped.
#   tmux-bindings.py  BUG-05: Prefix-E / Prefix-Space stay on the omni socket
#   first-run.py      BUG-06: first run uses the sibling omni-config
for t in tmux-bindings.py first-run.py; do
    if command -v python3 >/dev/null 2>&1; then
        rc=0
        python3 "$ROOT/packaging/tests/$t" || rc=$?
        [ "$rc" -eq 0 ] || [ "$rc" -eq 77 ] || fail "$t"
    else
        echo "$t: SKIP (python3 not installed)"
    fi
done

OMNI_TERM_AI_HOME="$ROOT" "$STAGE/usr/bin/omni-secret" backend >/dev/null \
    || fail "omni-secret backend"

echo "verify-install: OK ($STAGE layout checked)"
