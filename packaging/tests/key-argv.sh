#!/bin/sh
# IMP-04: a secret must not appear in ps during store or an FIM request,
# and a secret-tool item stored before the service attribute still resolves.
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
fail() { echo "FAIL: $*" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "key-argv: SKIP (no python3)"; exit 77; }
command -v nvim >/dev/null 2>&1 || { echo "key-argv: SKIP (no nvim)"; exit 77; }

KEY=omni-secret-argv-marker-9f3a
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
export OMNI_TERM_AI_HOME="$ROOT"
export XDG_CONFIG_HOME="$work/config"

# secret-tool: record argv, sleep on store so ps can see it, migrate on lookup.
cat > "$work/bin/secret-tool" << EOF
#!/bin/sh
printf '%s\\n' "\$*" >> "$work/secret-tool.args"
case "\$1" in
store)
    touch "$work/secret-tool.ready"
    sleep 2
    cat > "$work/secret-tool.stdin"
    ;;
lookup)
    if printf '%s' "\$*" | grep -F 'service omni-term-ai' >/dev/null; then
        if [ -f "$work/migrated" ]; then
            printf '%s' "$KEY"
        fi
    else
        printf '%s' "$KEY"
    fi
    ;;
esac
exit 0
EOF
chmod 755 "$work/bin/secret-tool"

# security: record argv, read the prompted password, sleep so ps can see it.
cat > "$work/bin/security" << EOF
#!/bin/sh
printf '%s\\n' "\$*" >> "$work/security.args"
touch "$work/security.ready"
sleep 1
IFS= read -r line || true
printf '%s' "\$line" > "$work/security.got"
exit 0
EOF
chmod 755 "$work/bin/security"

ps_args() {
    name=$1
    pids=$(ps -eo pid,args | awk -v n="$name" 'index($0, n) && index($0, "nvim") == 0 && !/awk/ { print $1 }')
    out=
    for pid in $pids; do
        if [ -r "/proc/$pid/cmdline" ]; then
            out="$out $(tr '\000' ' ' < "/proc/$pid/cmdline")"
        fi
        out="$out $(ps -ww -p "$pid" -o args= 2>/dev/null || true)"
    done
    printf '%s\n' "$out"
}

# Store via secret-tool. The key is on stdin, not argv.
(
    PATH="$work/bin:/usr/bin:/bin" OMNI_SECRET_BACKEND=secret-tool \
        "$ROOT/omni-secret" store deepseek << EOF
$KEY
EOF
) >/dev/null 2>&1 &
store_pid=$!
i=0
while [ ! -f "$work/secret-tool.ready" ] && [ "$i" -lt 50 ]; do
    i=$((i + 1))
    sleep 0.05
done
[ -f "$work/secret-tool.ready" ] || fail "secret-tool store did not start"
seen=$(ps_args secret-tool)
printf '%s\n' "$seen" | grep -F "$KEY" >/dev/null && fail "ps showed the key during secret-tool store: $seen"
wait "$store_pid" || fail "secret-tool store failed"
grep -F 'service omni-term-ai' "$work/secret-tool.args" >/dev/null || fail "store did not set service"
grep -F "$KEY" "$work/secret-tool.args" >/dev/null && fail "secret-tool argv contained the key"

# Old attribute still resolves, and the read copies it forward.
rm -f "$work/secret-tool.args"
got=$(PATH="$work/bin:/usr/bin:/bin" OMNI_SECRET_BACKEND=secret-tool "$ROOT/omni-secret" get deepseek)
[ "$got" = "$KEY" ] || fail "old secret-tool item was not found: [$got]"
grep -F 'service omni-term-ai' "$work/secret-tool.args" >/dev/null || fail "lookup did not migrate the old item"
touch "$work/migrated"
got=$(PATH="$work/bin:/usr/bin:/bin" OMNI_SECRET_BACKEND=secret-tool "$ROOT/omni-secret" get deepseek)
[ "$got" = "$KEY" ] || fail "namespaced lookup failed: [$got]"

# macOS keychain store must not put the key on argv, and must still deliver it.
(
    PATH="$work/bin:/usr/bin:/bin" OMNI_SECRET_BACKEND=security \
        "$ROOT/omni-secret" store openai << EOF
$KEY
EOF
) >/dev/null 2>&1 &
sec_pid=$!
i=0
while [ ! -f "$work/security.ready" ] && [ "$i" -lt 50 ]; do
    i=$((i + 1))
    sleep 0.05
done
[ -f "$work/security.ready" ] || fail "security store did not start"
seen=$(ps_args security)
printf '%s\n' "$seen" | grep -F "$KEY" >/dev/null && fail "ps showed the key during security store: $seen"
seen=$(ps_args python3)
printf '%s\n' "$seen" | grep -F "$KEY" >/dev/null && fail "ps showed the key in python3: $seen"
wait "$sec_pid" || fail "security store failed"
got=$(cat "$work/security.got")
[ "$got" = "$KEY" ] || fail "security did not receive the key off argv: [$got]"
grep -F -- '-w' "$work/security.args" >/dev/null || fail "security was not asked to prompt"
grep -F "$KEY" "$work/security.args" >/dev/null && fail "security argv contained the key"

# FIM curl must not put the key on argv.
cat > "$work/bin/curl" << EOF
#!/bin/sh
printf '%s\\n' "\$*" >> "$work/curl.args"
touch "$work/curl.ready"
sleep 2
exit 0
EOF
chmod 755 "$work/bin/curl"
printf '%s\n' "$KEY" > "$work/key"
(
    PATH="$work/bin:/usr/bin:/bin" nvim --headless -u NONE \
        --cmd "set rtp^=$ROOT/nvim-config" \
        -c "lua local h = 'Authorization: Bearer ' .. vim.fn.readfile('$work/key')[1]; require('omni_fim')._test_start_curl('https://example.invalid/completions', h)" \
        -c 'sleep 3' -c qa
) >/dev/null 2>&1 &
nvim_pid=$!
i=0
while [ ! -f "$work/curl.ready" ] && [ "$i" -lt 50 ]; do
    i=$((i + 1))
    sleep 0.05
done
[ -f "$work/curl.ready" ] || fail "curl request did not start"
seen=$(ps_args curl)
printf '%s\n' "$seen" | grep -F "$KEY" >/dev/null && fail "ps showed the key during FIM curl: $seen"
wait "$nvim_pid" || true
grep -F "$KEY" "$work/curl.args" >/dev/null && fail "curl argv contained the key: $(cat "$work/curl.args")"
grep -F -- '--config' "$work/curl.args" >/dev/null || fail "curl did not use a config file"

echo "key-argv: OK"
