# Locate OMNI_TERM_AI_HOME and source lib/omni.sh. Sourced from launcher scripts.
# shellcheck shell=sh

omni_boot() {
    if [ -n "${OMNI_TERM_AI_HOME:-}" ] && [ -f "${OMNI_TERM_AI_HOME}/lib/omni.sh" ]; then
        return 0
    fi
    if [ -d "@OMNI_HOME@" ] && [ -f "@OMNI_HOME@/lib/omni.sh" ]; then
        OMNI_TERM_AI_HOME="@OMNI_HOME@"
        export OMNI_TERM_AI_HOME
        return 0
    fi
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
    bindir=$(CDPATH= cd -P -- "$(dirname "$target")" && pwd) || exit 1
    if [ -f "$bindir/lib/omni.sh" ]; then
        OMNI_TERM_AI_HOME=$bindir
        export OMNI_TERM_AI_HOME
        return 0
    fi
    if [ -f "$bindir/../share/omni-term-ai/lib/omni.sh" ]; then
        OMNI_TERM_AI_HOME=$(CDPATH= cd -P -- "$bindir/../share/omni-term-ai" && pwd) || exit 1
        export OMNI_TERM_AI_HOME
        return 0
    fi
    echo "omni-term-ai: cannot locate installation (set OMNI_TERM_AI_HOME)" >&2
    exit 1
}

omni_boot
# shellcheck source=/dev/null
. "$OMNI_TERM_AI_HOME/lib/omni.sh"
