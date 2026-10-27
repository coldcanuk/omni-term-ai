#!/bin/sh
# Geometry of omni-watch-row on a private tmux server.
# R1 top-left pane is 24 rows and the watch pane is 80 by 24
# R2 the new pane runs OMNI_WATCH_CMD
# R3 a second call on the same pane does not add a pane
# R4 a pane narrower than 82 columns exits non-zero and leaves the original process
set -eu

ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'env -u TMUX TMUX_TMPDIR="$tmp" tmux kill-server >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

if ! command -v tmux >/dev/null 2>&1; then
    echo "watch-row: SKIP (tmux not installed)"
    exit 77
fi

chmod +x "$ROOT/omni-watch-row"
env -u TMUX TMUX_TMPDIR="$tmp" tmux -f /dev/null new-session -d -s probe -x 220 -y 60 'printf ASSISTANT; sleep 60'

t() {
    env -u TMUX TMUX_TMPDIR="$tmp" tmux "$@"
}

run_row() {
    env -u TMUX TMUX_TMPDIR="$tmp" PATH="$ROOT:$PATH" OMNI_WATCH_CMD='printf WATCH; sleep 60' \
        "$ROOT/omni-watch-row" "$1"
}

pane=$(t display-message -p -t probe:0.0 '#{pane_id}')
run_row "$pane"

# R1 top-left pane is 24 rows and the watch pane is 80 by 24
left=$(t list-panes -t probe:0 -F '#{pane_width}x#{pane_height} #{pane_top} #{pane_left}' |
    awk '$2 == 0 && $3 == 0 { print $1; exit }')
right=$(t list-panes -t probe:0 -F '#{pane_width}x#{pane_height} #{pane_top} #{pane_left}' |
    awk '$2 == 0 && $3 != 0 { print $1; exit }')
[ "$left" = "139x24" ] || fail "left pane is '$left', want 139x24"
[ "$right" = "80x24" ] || fail "watch pane is '$right', want 80x24"

# R2 the new pane runs OMNI_WATCH_CMD
sleep 1
watch_text=$(t capture-pane -p -t probe:0.1)
printf '%s\n' "$watch_text" | grep -q WATCH || fail "watch pane did not show WATCH"
assist_text=$(t capture-pane -p -t probe:0.0)
printf '%s\n' "$assist_text" | grep -q ASSISTANT || fail "assistant pane lost ASSISTANT"

count=$(t list-panes -t probe:0 | wc -l)
count=$(printf '%s' "$count" | tr -d ' ')
# R3 a second call on the same pane does not add a pane
run_row "$pane"
count2=$(t list-panes -t probe:0 | wc -l)
count2=$(printf '%s' "$count2" | tr -d ' ')
[ "$count2" = "$count" ] || fail "second call changed pane count from $count to $count2"

# R4 a pane narrower than 82 columns exits non-zero and leaves the original process
env -u TMUX TMUX_TMPDIR="$tmp" tmux -f /dev/null new-session -d -s narrow -x 70 -y 40 'printf NARROW; sleep 60'
npane=$(t display-message -p -t narrow:0.0 '#{pane_id}')
if env -u TMUX TMUX_TMPDIR="$tmp" PATH="$ROOT:$PATH" OMNI_WATCH_CMD='printf NO; sleep 60' \
    "$ROOT/omni-watch-row" "$npane"; then
    fail "narrow pane should exit non-zero"
fi
ncount=$(t list-panes -t narrow:0 | wc -l)
ncount=$(printf '%s' "$ncount" | tr -d ' ')
[ "$ncount" = 1 ] || fail "narrow session has $ncount panes"
t capture-pane -p -t narrow:0.0 | grep -q NARROW || fail "narrow process was disturbed"

echo "watch-row: ok"
