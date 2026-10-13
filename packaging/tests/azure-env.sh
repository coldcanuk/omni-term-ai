#!/bin/sh
# BUG-04: Azure key, endpoint, and deployment reach tmux. Empty key is not planted.
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
OMNI_TERM_AI_HOME=$ROOT
export OMNI_TERM_AI_HOME
XDG_CONFIG_HOME=$(mktemp -d)
export XDG_CONFIG_HOME

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

# shellcheck source=/dev/null
. "$ROOT/lib/omni.sh"

sentinel=$XDG_CONFIG_HOME/PWNED
endpoint="https://example.openai.azure.com; touch $sentinel"
deployment='my-deployment'

"$ROOT/omni-config" set azure-endpoint "$endpoint" >/dev/null
"$ROOT/omni-config" set azure-deployment "$deployment" >/dev/null
got_ep=$("$ROOT/omni-config" get azure-endpoint)
got_dep=$("$ROOT/omni-config" get azure-deployment)
if [ "$got_ep" != "$endpoint" ]; then
    fail "endpoint did not round-trip (got [$got_ep])"
fi
if [ "$got_dep" != "$deployment" ]; then
    fail "deployment did not round-trip (got [$got_dep])"
fi
if [ -e "$sentinel" ]; then
    fail "endpoint value was executed"
fi

omni_secret_get() {
    if [ "$1" = azure ] && [ -n "${FAKE_AZURE:-}" ]; then
        printf '%s' "$FAKE_AZURE"
    fi
    return 0
}
omni_tmux() {
    printf '%s\n' "$*" >>"$LOG"
}

LOG=$(mktemp)
FAKE_AZURE=azure-secret
unset AZURE_OPENAI_API_KEY AZURE_OPENAI_ENDPOINT AZURE_OPENAI_DEPLOYMENT || true
unset OMNI_AZURE_ENDPOINT OMNI_AZURE_DEPLOYMENT || true
omni_load_config
omni_export_harness_keys
omni_apply_azure_config
: >"$LOG"
omni_publish_tmux_secrets

grep -F 'set-environment -g AZURE_OPENAI_API_KEY azure-secret' "$LOG" >/dev/null \
    || fail "tmux did not receive the Azure key"
grep -F "set-environment -g AZURE_OPENAI_ENDPOINT $endpoint" "$LOG" >/dev/null \
    || fail "tmux did not receive the Azure endpoint"
grep -F "set-environment -g AZURE_OPENAI_DEPLOYMENT $deployment" "$LOG" >/dev/null \
    || fail "tmux did not receive the Azure deployment"
if [ -e "$sentinel" ]; then
    fail "publishing the endpoint executed it"
fi

# No stored secret and no ambient key: do not plant an empty AZURE_OPENAI_API_KEY.
FAKE_AZURE=
unset AZURE_OPENAI_API_KEY || true
omni_export_harness_keys
: >"$LOG"
omni_publish_tmux_secrets
if grep -E 'set-environment -g AZURE_OPENAI_API_KEY$' "$LOG" >/dev/null; then
    fail "empty Azure key was planted in tmux"
fi
grep -F 'set-environment -g -u AZURE_OPENAI_API_KEY' "$LOG" >/dev/null \
    || fail "missing Azure key was not unset in tmux"

# Empty config must not clobber an ambient endpoint.
unset OMNI_AZURE_ENDPOINT OMNI_AZURE_DEPLOYMENT || true
printf '%s\n' 'OMNI_AZURE_ENDPOINT=' 'OMNI_AZURE_DEPLOYMENT=' >"$(omni_config_path)"
AZURE_OPENAI_ENDPOINT=from-bashrc
export AZURE_OPENAI_ENDPOINT
omni_load_config
omni_apply_azure_config
if [ "$AZURE_OPENAI_ENDPOINT" != from-bashrc ]; then
    fail "empty config clobbered ambient endpoint (got [$AZURE_OPENAI_ENDPOINT])"
fi
: >"$LOG"
omni_publish_tmux_secrets
grep -F 'set-environment -g AZURE_OPENAI_ENDPOINT from-bashrc' "$LOG" >/dev/null \
    || fail "ambient endpoint was not published"

echo "azure-env: OK"
