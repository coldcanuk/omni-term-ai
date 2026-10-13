#!/bin/sh
# BUG-07: FIM provider is explicit. A stored OpenAI key does not replace DeepSeek.
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
XDG_CONFIG_HOME=$(mktemp -d)
export XDG_CONFIG_HOME OMNI_TERM_AI_HOME=$ROOT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}
command -v nvim >/dev/null 2>&1 || fail "nvim is required (CI installs it)"

"$ROOT/omni-config" set fim-provider deepseek >/dev/null
if [ "$("$ROOT/omni-config" get fim-provider)" != deepseek ]; then
    fail "default provider did not stick"
fi
if "$ROOT/omni-config" set fim-provider bogus >/dev/null 2>&1; then
    fail "bogus provider was accepted"
fi

out=$(nvim --headless -u NONE --cmd "set rtp^=$ROOT/nvim-config" \
    -c 'lua local M=require("omni_fim"); local both={OPENAI_API_KEY="o", DEEPSEEK_API_KEY="d"}; local d=M.endpoint_for({OMNI_FIM_PROVIDER="deepseek", OPENAI_API_KEY="o", DEEPSEEK_API_KEY="d"}); local o=M.endpoint_for({OMNI_FIM_PROVIDER="openai", OPENAI_API_KEY="o", DEEPSEEK_API_KEY="d"}); if d ~= "https://api.deepseek.com/beta/completions" then error("deepseek got "..tostring(d)) end; if o ~= "https://api.openai.com/v1/completions" then error("openai got "..tostring(o)) end; if not tostring(d):find("deepseek", 1, true) then error("not deepseek") end; if tostring(o):find("deepseek", 1, true) then error("openai called deepseek") end; print("lua-ok")' \
    -c qa 2>&1) || fail "nvim failed: $out"
printf '%s\n' "$out" | grep -F lua-ok >/dev/null || fail "lua check missing: $out"

# Bash completion uses the same provider, and does not call the network in dry mode.
py=$(python3 -c '
from pathlib import Path
text = Path("'"$ROOT"'/lib/deepseek-completion.bash").read_text()
start = text.index("import sys, json")
end = text.index("'\'' \"$prefix\"")
print(text[start:end])
')
got=$(OMNI_FIM_DRY=1 OMNI_FIM_PROVIDER=deepseek DEEPSEEK_API_KEY=d OPENAI_API_KEY=o \
    python3 -c "$py" 'echo hi' '')
if [ "$got" != "https://api.deepseek.com/beta/completions" ]; then
    fail "bash deepseek endpoint was [$got]"
fi
got=$(OMNI_FIM_DRY=1 OMNI_FIM_PROVIDER=openai DEEPSEEK_API_KEY=d OPENAI_API_KEY=o \
    python3 -c "$py" 'echo hi' '')
if [ "$got" != "https://api.openai.com/v1/completions" ]; then
    fail "bash openai endpoint was [$got]"
fi
printf '%s\n' "$got" | grep -F deepseek >/dev/null && fail "openai provider still selected deepseek"

echo "fim-provider: OK"
