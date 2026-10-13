#!/bin/sh
# BUG-01: config values round-trip and are never executed.
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
OMNI_TERM_AI_HOME=$ROOT
export OMNI_TERM_AI_HOME
XDG_CONFIG_HOME=$(mktemp -d)
export XDG_CONFIG_HOME
trap 'rm -rf "$XDG_CONFIG_HOME"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

# shellcheck source=/dev/null
. "$ROOT/lib/omni.sh"

CFG=$(omni_config_path)
SENTINEL=$XDG_CONFIG_HOME/PWNED

assert_eq() {
    if [ "$1" != "$2" ]; then
        printf 'FAIL: expected [%s] got [%s]\n' "$2" "$1" >&2
        exit 1
    fi
}

assert_untouched() {
    if [ -e "$SENTINEL" ]; then
        fail "config execution created $SENTINEL"
    fi
}

roundtrip() {
    value=$1
    "$ROOT/omni-config" set jumpbox "$value" >/dev/null
    got=$("$ROOT/omni-config" get jumpbox)
    assert_eq "$got" "$value"
    assert_untouched
}

# Metacharacters that used to execute or be corrupted by sed.
roundtrip 'user@jump.example.com; printf hi-from-config'
roundtrip "user@host\`printf hi\`"
roundtrip 'user@host$(printf hi)'
roundtrip 'user@host&injected'
roundtrip 'user@host|injected'
roundtrip "user@host'quote"
roundtrip 'user@host"dq'
roundtrip 'user@host name'
roundtrip 'user@host*'
roundtrip ''
roundtrip 'a\b'
roundtrip "a'b'c"

# Direct hostile file: the old sourcer would run these. The reader must not.
mkdir -p "$(dirname "$CFG")"
printf '%s\n' "OMNI_JUMPBOX=user@host; touch $SENTINEL" >"$CFG"
unset OMNI_JUMPBOX || true
omni_load_config
assert_eq "$OMNI_JUMPBOX" "user@host; touch $SENTINEL"
assert_untouched

printf '%s\n' "OMNI_JUMPBOX=\$(touch $SENTINEL)" >"$CFG"
unset OMNI_JUMPBOX || true
omni_load_config
assert_eq "$OMNI_JUMPBOX" "\$(touch $SENTINEL)"
assert_untouched

printf '%s\n' "EVIL=\$(touch $SENTINEL)" "OMNI_LEFT_HARNESS=codex" >"$CFG"
unset OMNI_LEFT_HARNESS || true
omni_load_config 2>/dev/null
assert_eq "$OMNI_LEFT_HARNESS" "codex"
assert_untouched

# Legacy unquoted and double-quoted files still load, without expansion.
cat >"$CFG" <<'EOF'
# comment
OMNI_LEFT_HARNESS=codex
OMNI_RIGHT_HARNESS=claude
OMNI_JUMPBOX=
OMNI_FIM_ENGINE=none
EOF
unset OMNI_LEFT_HARNESS OMNI_RIGHT_HARNESS OMNI_JUMPBOX OMNI_FIM_ENGINE || true
omni_load_config
assert_eq "$OMNI_LEFT_HARNESS" "codex"
assert_eq "$OMNI_RIGHT_HARNESS" "claude"
assert_eq "$OMNI_JUMPBOX" ""
assert_eq "$OMNI_FIM_ENGINE" "none"

printf '%s\n' "OMNI_JUMPBOX=\"user@host \$(touch $SENTINEL)\"" >"$CFG"
unset OMNI_JUMPBOX || true
omni_load_config
assert_eq "$OMNI_JUMPBOX" "user@host \$(touch $SENTINEL)"
assert_untouched

# Newlines are rejected and must not be written.
if "$ROOT/omni-config" set jumpbox "$(printf 'a\nb')" >/dev/null 2>&1; then
    fail "newline value was accepted"
fi

# Missing file still defaults, and does not require a sourced file.
rm -f "$CFG"
unset OMNI_LEFT_HARNESS OMNI_RIGHT_HARNESS OMNI_FIM_ENGINE || true
omni_load_config
assert_eq "$OMNI_LEFT_HARNESS" "agy"
assert_eq "$OMNI_RIGHT_HARNESS" "grok"
assert_eq "$OMNI_FIM_ENGINE" "native"

echo "config-roundtrip: OK"
