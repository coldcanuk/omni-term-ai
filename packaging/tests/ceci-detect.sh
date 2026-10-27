#!/bin/sh
# R1 a pane line with /cecicela and --watch and --work-dir runs ceci with that directory
# R2 a pane that shows /cecicela without --watch is not split
# R3 a second detect pass does not add another pane
# R4 launch-ai-workspace starts omni-ceci-detect from attach_or_switch
set -eu

ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'env -u TMUX TMUX_TMPDIR="$tmp" tmux kill-server >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

if ! command -v tmux >/dev/null 2>&1; then
    echo "ceci-detect: SKIP (tmux not installed)"
    exit 77
fi

mkdir -p "$tmp/bin"
cat > "$tmp/bin/ceci" <<EOF
#!/bin/sh
printf '%s\n' "\$*" > "$tmp/args"
exec sleep 60
EOF
chmod +x "$tmp/bin/ceci" "$ROOT/omni-ceci-detect" "$ROOT/omni-watch-row"

env -u TMUX TMUX_TMPDIR="$tmp" tmux -f /dev/null new-session -d -s hit -x 220 -y 60
env -u TMUX TMUX_TMPDIR="$tmp" tmux -f /dev/null new-session -d -s miss -x 220 -y 60
env -u TMUX TMUX_TMPDIR="$tmp" tmux send-keys -t hit:0.0 "printf '%s\n' '/cecicela --work-dir /tmp/ceci-demo --watch'" C-m
env -u TMUX TMUX_TMPDIR="$tmp" tmux send-keys -t miss:0.0 "printf '%s\n' '/cecicela status'" C-m
sleep 1

env -u TMUX TMUX_TMPDIR="$tmp" PATH="$tmp/bin:$ROOT:$PATH" "$ROOT/omni-ceci-detect" --once

# R1 a pane line with /cecicela and --watch and --work-dir runs ceci with that directory
[ -f "$tmp/args" ] || fail "ceci was not started"
grep -F 'status' "$tmp/args" >/dev/null || fail "ceci args missing status: $(cat "$tmp/args")"
grep -F -- '--work-dir' "$tmp/args" >/dev/null || fail "ceci args missing --work-dir: $(cat "$tmp/args")"
grep -F '/tmp/ceci-demo' "$tmp/args" >/dev/null || fail "ceci args missing work dir: $(cat "$tmp/args")"
grep -F -- '--watch' "$tmp/args" >/dev/null || fail "ceci args missing --watch: $(cat "$tmp/args")"
right=$(env -u TMUX TMUX_TMPDIR="$tmp" tmux list-panes -t hit:0 -F '#{pane_width}x#{pane_height} #{pane_top}' |
    awk '$2 == 0 && $1 == "80x24" { print $1; exit }')
[ "$right" = "80x24" ] || fail "watch pane missing on hit session"

# R2 a pane that shows /cecicela without --watch is not split
miss_count=$(env -u TMUX TMUX_TMPDIR="$tmp" tmux list-panes -t miss:0 | wc -l)
miss_count=$(printf '%s' "$miss_count" | tr -d ' ')
[ "$miss_count" = 1 ] || fail "miss session has $miss_count panes"

hit_count=$(env -u TMUX TMUX_TMPDIR="$tmp" tmux list-panes -t hit:0 | wc -l)
hit_count=$(printf '%s' "$hit_count" | tr -d ' ')
# R3 a second detect pass does not add another pane
env -u TMUX TMUX_TMPDIR="$tmp" PATH="$tmp/bin:$ROOT:$PATH" "$ROOT/omni-ceci-detect" --once
hit_count2=$(env -u TMUX TMUX_TMPDIR="$tmp" tmux list-panes -t hit:0 | wc -l)
hit_count2=$(printf '%s' "$hit_count2" | tr -d ' ')
[ "$hit_count2" = "$hit_count" ] || fail "second pass changed hit panes from $hit_count to $hit_count2"

# R4 launch-ai-workspace starts omni-ceci-detect from attach_or_switch
awk '
    /attach_or_switch\(\)/ { inside = 1 }
    inside && /omni-ceci-detect/ { found = 1 }
    inside && /^}/ { if (found) ok = 1; inside = 0 }
    END { exit ok ? 0 : 1 }
' "$ROOT/launch-ai-workspace" || fail "attach_or_switch does not start omni-ceci-detect"

echo "ceci-detect: ok"
