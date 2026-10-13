#!/bin/sh
# BUG-02: jumpbox default does not sshfs the jumpbox; @target is one quoted arg.
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
OMNI_TERM_AI_HOME=$ROOT
export OMNI_TERM_AI_HOME

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

# shellcheck source=/dev/null
. "$ROOT/lib/omni.sh"

SENTINEL=$(mktemp -d)/PWNED
assert_absent() {
    if [ -e "$SENTINEL" ]; then
        fail "sentinel was created: $*"
    fi
}

# Hostile target is one quoted assignment. Sourcing that line must not run.
payload="prod; touch $SENTINEL"
script=$(omni_jumpbox_target_script "$payload")
printf '%s\n' "$script" | grep -F "target='prod; touch $SENTINEL'" >/dev/null \
    || fail "target was not a single-quoted literal"
printf '%s\n' "$script" | grep -F 'sshfs -- "$target":/' >/dev/null \
    || fail "sshfs is not bound to the quoted target"
printf '%s\n' "$script" | grep -F '|| echo' >/dev/null \
    && fail "sshfs failure is still swallowed"
# The assignment line itself must not execute the payload.
# shellcheck disable=SC1090
sh -c "$(printf '%s\n' "$script" | head -n 2)"
assert_absent "quoted assignment"

# sshfs missing, or sshfs failing, must abort before launch-ai-workspace.
if sh -c "$script"; then
    fail "missing sshfs did not abort"
fi
assert_absent "missing sshfs"

failbin=$(mktemp -d)
cat >"$failbin/sshfs" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod 755 "$failbin/sshfs"
if PATH="$failbin:$PATH" sh -c "$script"; then
    fail "failing sshfs did not abort"
fi
assert_absent "failing sshfs"

# Spaces stay one argument.
spaced=$(omni_jumpbox_target_script 'prod host')
printf '%s\n' "$spaced" | grep -F "target='prod host'" >/dev/null \
    || fail "space was not kept inside one quoted target"

# Newlines are rejected.
if omni_jumpbox_target_script "$(printf 'a\nb')" >/dev/null 2>&1; then
    fail "newline target was accepted"
fi

# Launcher: fake ssh records argv. No real connection.
logdir=$(mktemp -d)
export OMNI_SSH_LOG=$logdir/ssh.log
export XDG_CONFIG_HOME=$logdir/config
mkdir -p "$XDG_CONFIG_HOME/omni-term-ai" "$logdir/bin"
cat >"$XDG_CONFIG_HOME/omni-term-ai/config" <<'EOF'
OMNI_LEFT_HARNESS=agy
OMNI_RIGHT_HARNESS=grok
OMNI_JUMPBOX=user@jump.example.com
OMNI_FIM_ENGINE=native
EOF
cat >"$logdir/bin/ssh" <<'EOF'
#!/bin/sh
: > "$OMNI_SSH_LOG"
for a in "$@"; do
    printf '%s\n' "$a"
    printf '\n---\n'
done >> "$OMNI_SSH_LOG"
exit 0
EOF
chmod 755 "$logdir/bin/ssh"

PATH="$logdir/bin:$PATH" "$ROOT/launch-ai-workspace" >/dev/null
log=$(cat "$OMNI_SSH_LOG")
printf '%s\n' "$log" | grep -F -- '-t' >/dev/null || fail "no-arg ssh missing -t"
printf '%s\n' "$log" | grep -F -- 'user@jump.example.com' >/dev/null || fail "no-arg ssh missing jumpbox"
printf '%s\n' "$log" | grep -F -- 'OMNI_SKIP_JUMPBOX=1 exec launch-ai-workspace' >/dev/null \
    || fail "no-arg launch does not stay local on the jumpbox"
printf '%s\n' "$log" | grep -F 'sshfs' >/dev/null && fail "no-arg launch sshfs-mounts something"
printf '%s\n' "$log" | grep -F 'jump.example.com:/' >/dev/null && fail "no-arg launch mounts the jumpbox host"

: > "$OMNI_SSH_LOG"
PATH="$logdir/bin:$PATH" "$ROOT/launch-ai-workspace" '@prod' >/dev/null
log=$(cat "$OMNI_SSH_LOG")
printf '%s\n' "$log" | grep -F -- 'user@jump.example.com' >/dev/null || fail "@prod did not ssh to the jumpbox"
printf '%s\n' "$log" | grep -F "target='prod'" >/dev/null || fail "@prod target was not quoted"
printf '%s\n' "$log" | grep -F 'jump.example.com:/' >/dev/null && fail "@prod mounts the jumpbox host"
printf '%s\n' "$log" | grep -F 'sshfs -- "$target":/' >/dev/null || fail "@prod does not sshfs the target"

echo "jumpbox-args: OK"
