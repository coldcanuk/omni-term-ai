#!/bin/sh
# R1 moving the row down then up restores a top 24-row band and an 80 by 24 watch pane
# R2 moving left or right with no side neighbor flips the 80-column watch pane to the other side
# R3 a window with no marked watch row exits non-zero and keeps its pane
# R4 prefix Alt-h Alt-j Alt-k and Alt-l are bound to omni-watch-move
set -eu

ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'env -u TMUX TMUX_TMPDIR="$tmp" tmux kill-server >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

if ! command -v tmux >/dev/null 2>&1; then
    echo "watch-move: SKIP (tmux not installed)"
    exit 77
fi

chmod +x "$ROOT/omni-watch-move" "$ROOT/omni-watch-row"
env -u TMUX TMUX_TMPDIR="$tmp" tmux -f /dev/null new-session -d -s move -x 220 -y 60 'printf BELOW; sleep 60'

t() {
    env -u TMUX TMUX_TMPDIR="$tmp" tmux "$@"
}

pane=$(t display-message -p -t move:0.0 '#{pane_id}')
env -u TMUX TMUX_TMPDIR="$tmp" PATH="$ROOT:$PATH" OMNI_WATCH_CMD='printf WATCH; sleep 60' \
    "$ROOT/omni-watch-row" "$pane"
sleep 1

move() {
    env -u TMUX TMUX_TMPDIR="$tmp" PATH="$ROOT:$PATH" "$ROOT/omni-watch-move" "$@"
}

move down "$pane"
# R1 moving the row down then up restores a top 24-row band and an 80 by 24 watch pane
down_top=$(t list-panes -t move:0 -F '#{pane_top} #{pane_width}x#{pane_height} #{pane_title}' |
    awk '$3 == "watch" { print $1; exit }')
[ -n "$down_top" ] || fail "watch pane title missing after move down"
below_top=$(t list-panes -t move:0 -F '#{pane_top}' | awk 'BEGIN{m=999} {if ($1+0<m) m=$1+0} END{print m}')
[ "$down_top" -gt "$below_top" ] || fail "row did not move below the other pane (watch top $down_top, other $below_top)"
move up "$pane"
watch_geom=$(t list-panes -t move:0 -F '#{pane_width}x#{pane_height} #{pane_top} #{pane_left} #{pane_title}' |
    awk '$4 == "watch" { print $1, $2, $3; exit }')
[ "$watch_geom" = "80x24 0 140" ] || fail "after up, watch pane is '$watch_geom', want 80x24 at top 0 left 140"
t capture-pane -p -t move:0.0 | grep -q BELOW || fail "assistant text left the top-left pane"

# R2 moving left or right with no side neighbor flips the 80-column watch pane to the other side
move right "$pane"
flipped=$(t list-panes -t move:0 -F '#{pane_width}x#{pane_height} #{pane_left} #{pane_title}' |
    awk '$3 == "watch" { print $1, $2; exit }')
[ "$flipped" = "80x24 0" ] || fail "flip put watch at '$flipped', want 80x24 left 0"
move left "$pane"
back=$(t list-panes -t move:0 -F '#{pane_width}x#{pane_height} #{pane_left} #{pane_title}' |
    awk '$3 == "watch" { print $1, $2; exit }')
[ "$back" = "80x24 140" ] || fail "second flip put watch at '$back', want 80x24 left 140"

# R3 a window with no marked watch row exits non-zero and keeps its pane
env -u TMUX TMUX_TMPDIR="$tmp" tmux -f /dev/null new-session -d -s plain -x 80 -y 24 'printf PLAIN; sleep 60'
plain=$(t display-message -p -t plain:0.0 '#{pane_id}')
if move down "$plain"; then
    fail "a plain pane should exit non-zero"
fi
pcount=$(t list-panes -t plain:0 | wc -l)
pcount=$(printf '%s' "$pcount" | tr -d ' ')
[ "$pcount" = 1 ] || fail "plain window has $pcount panes"
t capture-pane -p -t plain:0.0 | grep -q PLAIN || fail "plain pane was disturbed"

# R4 prefix Alt-h Alt-j Alt-k and Alt-l are bound to omni-watch-move
# A second socket, because -f is ignored once the geometry server is up.
keytmp=$tmp/keys
mkdir -p "$keytmp"
env -u TMUX TMUX_TMPDIR="$keytmp" tmux -f "$ROOT/tmux.conf" new-session -d -s keys -x 80 -y 24
keys=$(env -u TMUX TMUX_TMPDIR="$keytmp" tmux list-keys -T prefix)
env -u TMUX TMUX_TMPDIR="$keytmp" tmux kill-server
for key in M-h M-j M-k M-l; do
    printf '%s\n' "$keys" | grep -F "$key" | grep -F 'omni-watch-move' >/dev/null \
        || fail "prefix $key is not bound to omni-watch-move"
done

echo "watch-move: ok"
