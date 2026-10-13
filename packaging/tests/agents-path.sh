#!/bin/sh
# BUG-12: cleanup instructions must work in this clone.
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
fail() { echo "FAIL: $*" >&2; exit 1; }
if grep -q '/opt/repo' "$ROOT/AGENTS.md"; then
    fail "AGENTS.md still names /opt/repo"
fi
grep -q 'git worktree list --porcelain' "$ROOT/AGENTS.md" || fail "cleanup does not find the main worktree"
top=$(git -C "$ROOT" worktree list --porcelain | awk '/^worktree / { print substr($0, 10); exit }')
[ -n "$top" ] || fail "no main worktree"
git -C "$top" rev-parse --show-toplevel >/dev/null || fail "documented toplevel is not a repo"
echo "agents-path: OK"
