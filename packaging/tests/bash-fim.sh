#!/bin/bash
# BUG-08: bash FIM binds for the configured provider, inserts a picked choice,
# and does not abort when python3 is missing.
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
fail() { echo "FAIL: $*" >&2; exit 1; }

# Model text must never be evaluated.
if grep -n 'eval ' "$ROOT/lib/deepseek-completion.bash" | grep -v 'Never evals'; then
    fail "completion still evals model text"
fi

# OpenAI-only, provider openai, binds Ctrl-F. DeepSeek key absent.
# secret-tool is stubbed so a real keystore cannot change the result.
stub=$(mktemp -d)
printf '%s\n' '#!/bin/sh' 'exit 1' > "$stub/secret-tool"
chmod +x "$stub/secret-tool"
cfg=$(mktemp -d)
mkdir -p "$cfg/omni-term-ai"
printf '%s\n' 'OMNI_FIM_PROVIDER=openai' > "$cfg/omni-term-ai/config"
cfg_ds=$(mktemp -d)
mkdir -p "$cfg_ds/omni-term-ai"
printf '%s\n' 'OMNI_FIM_PROVIDER=deepseek' > "$cfg_ds/omni-term-ai/config"

bind_out=$(
    env -i \
        HOME="${HOME:-/tmp}" \
        PATH="$stub:/usr/bin:/bin" \
        TERM=xterm \
        XDG_CONFIG_HOME="$cfg" \
        OMNI_TERM_AI_HOME="$ROOT" \
        OPENAI_API_KEY=test-openai-only \
        bash --noprofile --norc -ic '. "$OMNI_TERM_AI_HOME/lib/omni-bash.sh"; bind -X'
) || fail "interactive bash did not bind Ctrl-F"
printf '%s\n' "$bind_out" | grep -F '_omni_deepseek_completion' >/dev/null || fail "Ctrl-F is not the FIM function: $bind_out"

# DeepSeek-only default still binds. OpenAI key alone, default provider, does not.
if env -i \
    HOME="${HOME:-/tmp}" \
    PATH="$stub:/usr/bin:/bin" \
    TERM=xterm \
    XDG_CONFIG_HOME="$cfg_ds" \
    OMNI_TERM_AI_HOME="$ROOT" \
    OPENAI_API_KEY=test-openai-only \
    OMNI_FIM_PROVIDER=deepseek \
    bash --noprofile --norc -ic '. "$OMNI_TERM_AI_HOME/lib/omni-bash.sh"; bind -X' 2>/dev/null | grep -F '_omni_deepseek_completion' >/dev/null; then
    fail "deepseek provider bound Ctrl-F with only an OpenAI key"
fi

# Two choices: pick 2, it lands in the line. A quote in the choice is not eval'd.
out=$(
    bash --noprofile --norc -c '
        set -eu
        . "'"$ROOT"'/lib/deepseek-completion.bash"
        READLINE_LINE="echo "
        READLINE_POINT=5
        export OMNI_FIM_PROVIDER=openai OPENAI_API_KEY=test
        export OMNI_FIM_FAKE_CHOICES="[\"one\", \"two; rm -rf /'\''\"]"
        export OMNI_FIM_PICK=2
        _omni_deepseek_completion
        printf "%s\n" "$READLINE_LINE"
        printf "POINT:%s\n" "$READLINE_POINT"
    '
)
printf '%s\n' "$out" | grep -F "echo two; rm -rf /'" >/dev/null || fail "pick 2 was not inserted: $out"
printf '%s\n' "$out" | grep -F 'POINT:19' >/dev/null || fail "cursor point wrong: $out"

# Missing python3 warns and returns. The shell continues.
miss=$(mktemp -d)
cont=$(
    env PATH="$miss" /usr/bin/bash --noprofile --norc -c '
        . "'"$ROOT"'/lib/deepseek-completion.bash"
        READLINE_LINE="echo"
        READLINE_POINT=4
        _omni_deepseek_completion
        echo CONTINUED
    ' 2>&1
) || fail "missing python3 aborted the shell"
printf '%s\n' "$cont" | grep -F 'python3 is required' >/dev/null || fail "no warning: $cont"
printf '%s\n' "$cont" | grep -F CONTINUED >/dev/null || fail "shell did not continue: $cont"

rm -rf "$stub" "$cfg" "$cfg_ds" "$miss"
echo "bash-fim: OK"
