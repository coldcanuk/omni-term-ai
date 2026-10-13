#!/bin/sh
# Omni-Exec: fetch API keys on the fly for a single command.
# Usage: omni-exec <command> [args...]
set -eu

# npm links these scripts. Resolve the symlink so lib/boot.sh is found
# next to the real file, not next to the bin directory.
omni_argv0_dir() {
    target=$0
    n=0
    while [ -L "$target" ] && [ "$n" -lt 40 ]; do
        n=$((n + 1))
        link=$(readlink "$target") || break
        case $link in
        /*) target=$link ;;
        *) target=$(dirname "$target")/$link ;;
        esac
    done
    CDPATH= cd -P -- "$(dirname "$target")" && pwd
}
script_dir=$(omni_argv0_dir) || exit 1

if [ -f "$script_dir/lib/boot.sh" ]; then
    # shellcheck source=lib/boot.sh
    . "$script_dir/lib/boot.sh"
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

# Inject stored harness keys. A missing secret is left unset so an ambient
# token or a browser login is not replaced with an empty string.
omni_export_harness_keys

exec "$@"
