# Shared helpers for Omni Term AI. Sourced after OMNI_TERM_AI_HOME is set.
# shellcheck shell=sh

omni_config_dir() {
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/omni-term-ai"
}

omni_secrets_dir() {
    printf '%s\n' "$(omni_config_dir)/secrets"
}

omni_ensure_nvim_config() {
    cfg=$(omni_config_dir)
    if [ ! -e "$cfg" ]; then
        mkdir -p "$(dirname "$cfg")"
        ln -s "$OMNI_TERM_AI_HOME/nvim-config" "$cfg"
    fi
}

omni_secret_backend() {
    if command -v secret-tool >/dev/null 2>&1; then
        printf '%s\n' secret-tool
    elif [ "$(uname -s)" = Darwin ] && command -v security >/dev/null 2>&1; then
        printf '%s\n' security
    elif command -v pass >/dev/null 2>&1; then
        printf '%s\n' pass
    else
        printf '%s\n' file
    fi
}

omni_secret_get() {
    name=$1
    backend=$(omni_secret_backend)
    case $backend in
    secret-tool)
        secret-tool lookup api "$name" 2>/dev/null || true
        ;;
    security)
        security find-generic-password -a "${USER:-$(id -un)}" -s "omni-term-ai.$name" -w 2>/dev/null || true
        ;;
    pass)
        pass show "omni-term-ai/$name" 2>/dev/null || true
        ;;
    file)
        f="$(omni_secrets_dir)/$name"
        if [ -f "$f" ]; then
            cat "$f"
        fi
        ;;
    esac
}

omni_secret_store() {
    name=$1
    value=$2
    backend=$(omni_secret_backend)
    case $backend in
    secret-tool)
        printf '%s' "$value" | secret-tool store --label="Omni Term AI $name API key" api "$name"
        ;;
    security)
        security add-generic-password -U -a "${USER:-$(id -un)}" -s "omni-term-ai.$name" -w "$value"
        ;;
    pass)
        printf '%s\n' "$value" | pass insert -e "omni-term-ai/$name"
        ;;
    file)
        d=$(omni_secrets_dir)
        mkdir -p "$d"
        chmod 700 "$d"
        f="$d/$name"
        old_umask=$(umask)
        umask 077
        printf '%s\n' "$value" >"$f"
        umask "$old_umask"
        chmod 600 "$f"
        echo "warning: stored $name in $f (mode 0600); prefer an OS keychain when available" >&2
        ;;
    esac
}

omni_tmux() {
    tmux -L omni-term-ai -f "$OMNI_TERM_AI_HOME/tmux.conf" "$@"
}
