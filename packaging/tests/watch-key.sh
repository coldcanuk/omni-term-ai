#!/bin/sh
# R1 tmux prefix W is bound to omni-watch-row
# R2 running that bound command on a 220 by 60 pane creates an 80 by 24 watch pane
# R3 README and the launch man page both name Prefix + Shift + W
set -eu

ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'env -u TMUX TMUX_TMPDIR="$tmp" tmux kill-server >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

if ! command -v tmux >/dev/null 2>&1; then
    echo "watch-key: SKIP (tmux not installed)"
    exit 77
fi

env -u TMUX TMUX_TMPDIR="$tmp" tmux -f "$ROOT/tmux.conf" new-session -d -s key -x 220 -y 60 'printf ASSISTANT; sleep 60'
keys=$(env -u TMUX TMUX_TMPDIR="$tmp" tmux list-keys -T prefix)
# R1 tmux prefix W is bound to omni-watch-row
printf '%s\n' "$keys" | grep -F 'omni-watch-row' | grep -F ' W ' >/dev/null \
    || fail "prefix W is not bound to omni-watch-row"

env -u TMUX TMUX_TMPDIR="$tmp" tmux set-environment -g PATH "$ROOT:$PATH"
env -u TMUX TMUX_TMPDIR="$tmp" tmux set-environment -g OMNI_WATCH_CMD 'printf WATCH; sleep 60'
# R2 running that bound command on a 220 by 60 pane creates an 80 by 24 watch pane
env -u TMUX TMUX_TMPDIR="$tmp" tmux run-shell "omni-watch-row"
sleep 1
right=$(env -u TMUX TMUX_TMPDIR="$tmp" tmux list-panes -t key:0 -F '#{pane_width}x#{pane_height}' |
    awk '$1 == "80x24" { print $1; exit }')
[ "$right" = "80x24" ] || fail "bound command did not open an 80x24 pane (got '${right:-none}')"
env -u TMUX TMUX_TMPDIR="$tmp" tmux capture-pane -p -t key:0.0 | grep -q ASSISTANT \
    || fail "assistant text left the top-left pane"

# R3 README and the launch man page both name Prefix + Shift + W
grep -F 'Prefix + Shift + W' "$ROOT/README.md" >/dev/null || fail "README omits Prefix + Shift + W"
man -l "$ROOT/man/launch-ai-workspace.1" | grep -F 'Prefix + Shift + W' >/dev/null \
    || fail "man page omits Prefix + Shift + W"

echo "watch-key: ok"
