#!/bin/sh
# IMP-06: sourcing the bash integration must not retarget nvim unless asked,
# and must load FIM settings through the config parser (not by sourcing).
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
fail() { echo "FAIL: $*" >&2; exit 1; }

stub=$(mktemp -d)
cfg=$(mktemp -d)
xdg=$(mktemp -d)
neg=$(mktemp)
sentinel="$xdg/ran"
trap 'rm -rf "$stub" "$cfg" "$xdg" "$neg"' EXIT

printf '%s\n' '#!/bin/sh' 'exit 1' > "$stub/secret-tool"
chmod +x "$stub/secret-tool"
mkdir -p "$cfg/omni-term-ai"
# Quoted on purpose. A semicolon must stay data.
printf '%s\n' "OMNI_FIM_ENGINE='copilot; touch $sentinel'" "OMNI_FIM_PROVIDER='openai'" > "$cfg/omni-term-ai/config"

source_bash() {
    env -i \
        HOME="${HOME:-/tmp}" \
        PATH="$stub:/usr/bin:/bin" \
        TERM=xterm \
        XDG_CONFIG_HOME="$cfg" \
        OMNI_TERM_AI_HOME="$ROOT" \
        "$@" \
        bash --noprofile --norc -c '
            . "$OMNI_TERM_AI_HOME/lib/omni-bash.sh"
            printf "APPNAME=[%s]\n" "${NVIM_APPNAME-}"
            printf "ENGINE=[%s]\n" "${OMNI_FIM_ENGINE-}"
            printf "PROVIDER=[%s]\n" "${OMNI_FIM_PROVIDER-}"
            if [ -e "$XDG_CONFIG_HOME/omni-term-ai/init.lua" ]; then
                printf "LINKED=yes\n"
            else
                printf "LINKED=no\n"
            fi
        '
}

out=$(source_bash) || fail "default source failed: $out"
printf '%s\n' "$out" | grep -F 'APPNAME=[]' >/dev/null || fail "sourcing changed NVIM_APPNAME: $out"
printf '%s\n' "$out" | grep -F "ENGINE=[copilot; touch $sentinel]" >/dev/null || fail "FIM engine was not loaded as data: $out"
printf '%s\n' "$out" | grep -F 'PROVIDER=[openai]' >/dev/null || fail "FIM provider was not loaded: $out"
printf '%s\n' "$out" | grep -F 'LINKED=no' >/dev/null || fail "sourcing linked the nvim config: $out"
[ ! -e "$sentinel" ] || fail "config value was executed"

out=$(source_bash NVIM_APPNAME=mine) || fail "preset source failed: $out"
printf '%s\n' "$out" | grep -F 'APPNAME=[mine]' >/dev/null || fail "preset NVIM_APPNAME was changed: $out"

out=$(source_bash OMNI_USE_NVIM_CONFIG=1) || fail "opt-in source failed: $out"
printf '%s\n' "$out" | grep -F 'APPNAME=[omni-term-ai]' >/dev/null || fail "opt-in did not set NVIM_APPNAME: $out"
printf '%s\n' "$out" | grep -F 'LINKED=yes' >/dev/null || fail "opt-in did not install the nvim config: $out"
rm -f "$cfg/omni-term-ai/init.lua" "$cfg/omni-term-ai/lua" "$cfg/omni-term-ai/lazy-lock.json"

out=$(source_bash OMNI_USE_NVIM_CONFIG=1 NVIM_APPNAME=mine) || fail "opt-in preset failed: $out"
printf '%s\n' "$out" | grep -F 'APPNAME=[mine]' >/dev/null || fail "opt-in overwrote NVIM_APPNAME: $out"
printf '%s\n' "$out" | grep -F 'LINKED=no' >/dev/null || fail "opt-in linked config for a different appname: $out"

# Negative control: without omni_load_config the engine stays unset, so this
# assertion is coupled to the parser call and not to a default.
sed '/omni_load_config/d' "$ROOT/lib/omni-bash.sh" > "$neg"
neg_out=$(
    env -i \
        HOME="${HOME:-/tmp}" \
        PATH="$stub:/usr/bin:/bin" \
        TERM=xterm \
        XDG_CONFIG_HOME="$cfg" \
        OMNI_TERM_AI_HOME="$ROOT" \
        bash --noprofile --norc -c '. "$1"; printf "ENGINE=[%s]\n" "${OMNI_FIM_ENGINE-}"' _ "$neg"
) || fail "negative control did not run: $neg_out"
printf '%s\n' "$neg_out" | grep -F 'ENGINE=[]' >/dev/null || fail "negative control still loaded the engine: $neg_out"

echo "shell-integration: OK"
