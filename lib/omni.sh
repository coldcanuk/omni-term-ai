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

# ---------------------------------------------------------------------------
# Harness registry: the shell AI assistants that can fill the two Command
# Center panes (top-left and top-right). Everything the launcher, omni-config,
# omni-exec, and omni-secret need to know about a harness lives here.
# ---------------------------------------------------------------------------

omni_harness_list() {
    cat <<-'EOF'
	grok
	agy
	copilot
	claude
	codex
	deepseek
	EOF
}

omni_valid_harness() {
    case $1 in
    grok | agy | copilot | claude | codex | deepseek) return 0 ;;
    *) return 1 ;;
    esac
}

omni_harness_name() {
    case $1 in
    grok) printf 'grok (xAI Grok Build)\n' ;;
    agy) printf 'agy (Google Antigravity)\n' ;;
    copilot) printf 'copilot (GitHub Copilot CLI)\n' ;;
    claude) printf 'claude (Claude Code)\n' ;;
    codex) printf 'codex (OpenAI Codex)\n' ;;
    deepseek) printf 'deepseek (DeepSeek Harness)\n' ;;
    esac
}

# Executable that must be on PATH for the harness to run.
omni_harness_bin() {
    case $1 in
    grok) printf 'grok\n' ;;
    agy) printf 'agy\n' ;;
    copilot) printf 'copilot\n' ;;
    claude) printf 'claude\n' ;;
    codex) printf 'codex\n' ;;
    deepseek) printf 'dsh\n' ;;
    esac
}

# Command actually sent to the pane (binary plus any launch args).
omni_harness_cmd() {
    case $1 in
    deepseek) printf 'dsh web --no-open\n' ;;
    *) omni_harness_bin "$1" ;;
    esac
}

# Primary API-key environment variable the harness reads for auth.
omni_harness_env() {
    case $1 in
    grok) printf 'XAI_API_KEY\n' ;;
    agy) printf 'GEMINI_API_KEY\n' ;;
    copilot) printf 'GH_TOKEN\n' ;;
    claude) printf 'ANTHROPIC_API_KEY\n' ;;
    codex) printf 'OPENAI_API_KEY\n' ;;
    deepseek) printf 'DEEPSEEK_API_KEY\n' ;;
    esac
}

# One-line install command shown when the harness binary is missing.
omni_harness_install_hint() {
    case $1 in
    grok) printf 'curl -fsSL https://x.ai/cli/install.sh | bash\n' ;;
    agy) printf 'curl -fsSL https://antigravity.google/cli/install.sh | bash\n' ;;
    copilot) printf 'brew install copilot-cli   # or: curl -fsSL https://gh.io/copilot-install | bash\n' ;;
    claude) printf 'npm install -g @anthropic-ai/claude-code\n' ;;
    codex) printf 'npm install -g @openai/codex   # or: brew install --cask codex\n' ;;
    deepseek) printf 'npm install -g @deepseek-ai/dsh\n' ;;
    esac
}

# Exit 0 when the harness binary is installed, 1 otherwise.
omni_harness_installed() {
    bin=$(omni_harness_bin "$1") || return 1
    command -v "$bin" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Configuration: ~/.config/omni-term-ai/config (POSIX sh, sourced).
#   OMNI_LEFT_HARNESS=agy      # top-left Command Center pane
#   OMNI_RIGHT_HARNESS=grok    # top-right Command Center pane
# ---------------------------------------------------------------------------

omni_config_path() {
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/omni-term-ai/config"
}

# Load the config file; fall back to defaults when absent or unparsable.
omni_load_config() {
    cfg=$(omni_config_path)
    if [ -f "$cfg" ]; then
        # shellcheck source=/dev/null
        . "$cfg" 2>/dev/null || \
            echo "omni-term-ai: warning: could not parse $cfg; using defaults" >&2
    fi
    # Default only when a value is missing, never when it is invalid:
    # launch-ai-workspace reports invalid values so the user can fix their
    # config instead of silently getting a different harness.
    : "${OMNI_LEFT_HARNESS:=agy}"
    : "${OMNI_RIGHT_HARNESS:=grok}"
    export OMNI_LEFT_HARNESS OMNI_RIGHT_HARNESS
}

omni_config_get() {
    case $1 in
    left) printf '%s\n' "$OMNI_LEFT_HARNESS" ;;
    right) printf '%s\n' "$OMNI_RIGHT_HARNESS" ;;
    esac
}

# ---------------------------------------------------------------------------
# Key injection: every harness auth env var, fetched from the OS secret store.
# Unset secrets become empty strings so interactive logins still work.
# ---------------------------------------------------------------------------

omni_export_harness_keys() {
    XAI_KEY=$(omni_secret_get xai)
    DEEPSEEK_KEY=$(omni_secret_get deepseek)
    ANTHROPIC_KEY=$(omni_secret_get anthropic)
    OPENAI_KEY=$(omni_secret_get openai)
    GITHUB_KEY=$(omni_secret_get github)
    GEMINI_KEY=$(omni_secret_get gemini)
    export XAI_API_KEY="$XAI_KEY"
    export DEEPSEEK_API_KEY="$DEEPSEEK_KEY"
    export ANTHROPIC_API_KEY="$ANTHROPIC_KEY"
    export OPENAI_API_KEY="$OPENAI_KEY"
    export GH_TOKEN="$GITHUB_KEY"
    export GITHUB_TOKEN="$GITHUB_KEY"
    export GEMINI_API_KEY="$GEMINI_KEY"
}
