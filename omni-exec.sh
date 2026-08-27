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

# Inject every harness auth key from the OS secret store. Keys that were
# never stored become empty strings so interactive logins still work.
omni_export_harness_keys

exec "$@"
