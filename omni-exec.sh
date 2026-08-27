#!/bin/sh
# Omni-Exec: fetch API keys on the fly for a single command.
# Usage: omni-exec <command> [args...]
set -eu

if [ -f "$(dirname "$0")/lib/boot.sh" ]; then
    # shellcheck source=lib/boot.sh
    . "$(dirname "$0")/lib/boot.sh"
else
    OMNI_TERM_AI_HOME="${OMNI_TERM_AI_HOME:-@OMNI_HOME@}"
    export OMNI_TERM_AI_HOME
    # shellcheck source=/dev/null
    . "$OMNI_TERM_AI_HOME/lib/omni.sh"
fi

if [ $# -eq 0 ]; then
    echo "Usage: omni-exec <command> [args...]" >&2
    exit 1
fi

XAI_KEY=$(omni_secret_get xai)
DEEPSEEK_KEY=$(omni_secret_get deepseek)

export XAI_API_KEY="$XAI_KEY"
export DEEPSEEK_API_KEY="$DEEPSEEK_KEY"

exec "$@"
