#!/bin/sh
# BUG-03: a missing secret must not export an empty token over a real one.
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

# Isolate from the real keychain.
omni_secret_get() {
    if [ "$1" = github ] && [ -n "${FAKE_GITHUB:-}" ]; then
        printf '%s' "$FAKE_GITHUB"
        return 0
    fi
    return 0
}

unset XAI_API_KEY DEEPSEEK_API_KEY ANTHROPIC_API_KEY OPENAI_API_KEY GH_TOKEN GITHUB_TOKEN GEMINI_API_KEY AZURE_OPENAI_API_KEY || true
FAKE_GITHUB=
GH_TOKEN=from-keyring
export GH_TOKEN
omni_export_harness_keys
if [ "$GH_TOKEN" != from-keyring ]; then
    fail "empty secret clobbered ambient GH_TOKEN (got [$GH_TOKEN])"
fi
if [ "${GH_TOKEN+x}" != x ]; then
    fail "ambient GH_TOKEN was unset"
fi

# A stored secret still wins.
FAKE_GITHUB=from-store
GH_TOKEN=from-keyring
omni_export_harness_keys
if [ "$GH_TOKEN" != from-store ]; then
    fail "stored secret was not applied (got [$GH_TOKEN])"
fi
if [ "$GITHUB_TOKEN" != from-store ]; then
    fail "GITHUB_TOKEN was not applied (got [$GITHUB_TOKEN])"
fi

# An already-empty variable is unset, not left as "".
FAKE_GITHUB=
GH_TOKEN=
export GH_TOKEN
omni_export_harness_keys
if [ "${GH_TOKEN+x}" = x ]; then
    fail "empty GH_TOKEN was left set"
fi

# A secret containing shell metacharacters is data, not a command.
sentinel=$(mktemp -d)/PWNED
FAKE_GITHUB="stored; touch $sentinel"
unset GH_TOKEN || true
omni_export_harness_keys
if [ "$GH_TOKEN" != "stored; touch $sentinel" ]; then
    fail "metacharacter secret was not assigned literally"
fi
if [ -e "$sentinel" ]; then
    fail "secret value was executed"
fi

# tmux publish: non-empty ambient is copied; empty is unset, never set to "".
log=$(mktemp)
omni_tmux() {
    printf '%s\n' "$*" >>"$log"
}
FAKE_GITHUB=
GH_TOKEN=from-keyring
export GH_TOKEN
unset GITHUB_TOKEN || true
: >"$log"
omni_export_harness_keys
omni_publish_tmux_secrets
if ! grep -F 'set-environment -g GH_TOKEN from-keyring' "$log" >/dev/null; then
    fail "tmux did not receive the ambient token"
fi
if grep -E 'set-environment -g GH_TOKEN$' "$log" >/dev/null; then
    fail "tmux received an empty GH_TOKEN"
fi
if ! grep -F 'set-environment -g -u GITHUB_TOKEN' "$log" >/dev/null; then
    fail "empty GITHUB_TOKEN was not unset in tmux"
fi

# omni-exec, with secret-tool hidden so nothing is stored.
bindir=$(mktemp -d)
cat >"$bindir/secret-tool" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod 755 "$bindir/secret-tool"
got=$(GH_TOKEN=from-keyring PATH="$bindir:$PATH" "$ROOT/omni-exec.sh" sh -c 'printf %s "$GH_TOKEN"')
if [ "$got" != from-keyring ]; then
    fail "omni-exec clobbered GH_TOKEN (got [$got])"
fi

echo "empty-secrets: OK"
