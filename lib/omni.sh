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
    if [ -h "$cfg" ]; then rm -f "$cfg"; fi
    if [ ! -e "$cfg" ]; then mkdir -p "$cfg"; fi
    
    # Symlink Neovim config files directly into the directory
    ln -sfn "$OMNI_TERM_AI_HOME/nvim-config/init.lua" "$cfg/init.lua"
    ln -sfn "$OMNI_TERM_AI_HOME/nvim-config/lua" "$cfg/lua"
    ln -sfn "$OMNI_TERM_AI_HOME/nvim-config/lazy-lock.json" "$cfg/lazy-lock.json"
}

# OMNI_WSL=1 forces WSL behavior (tests). OMNI_WSL=0 forces a native host.
omni_is_wsl() {
    case ${OMNI_WSL-} in
    1) return 0 ;;
    0) return 1 ;;
    esac
    if [ -n "${WSL_DISTRO_NAME:-}" ] || [ -n "${WSL_INTEROP:-}" ]; then
        return 0
    fi
    if [ -r /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; then
        return 0
    fi
    return 1
}

# secret-tool hangs on WSL when the session bus is down. Do not select it then.
# OMNI_SESSION_BUS=0/1 overrides detection so tests do not depend on this host.
omni_session_bus_up() {
    case ${OMNI_SESSION_BUS-} in
    1) return 0 ;;
    0) return 1 ;;
    esac
    if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        return 0
    fi
    uid=$(id -u)
    if [ -S "/run/user/${uid}/bus" ]; then
        return 0
    fi
    return 1
}

omni_secret_tool_usable() {
    command -v secret-tool >/dev/null 2>&1 || return 1
    if omni_is_wsl; then
        omni_session_bus_up
        return
    fi
    return 0
}

omni_secret_backend() {
    if [ -n "${OMNI_SECRET_BACKEND:-}" ]; then
        printf '%s\n' "$OMNI_SECRET_BACKEND"
        return 0
    fi
    if omni_secret_tool_usable; then
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
        got=$(secret-tool lookup service omni-term-ai api "$name" 2>/dev/null || true)
        if [ -z "$got" ]; then
            got=$(secret-tool lookup api "$name" 2>/dev/null || true)
            if [ -n "$got" ]; then
                printf '%s' "$got" | secret-tool store --label="Omni Term AI $name API key" service omni-term-ai api "$name"
            fi
        fi
        printf '%s' "$got"
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
        printf '%s' "$value" | secret-tool store --label="Omni Term AI $name API key" service omni-term-ai api "$name"
        ;;
    security)
        omni_security_store "${USER:-$(id -un)}" "omni-term-ai.$name" "$value"
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

# Store a macOS keychain item without putting the secret on argv.
# security reads -w from the terminal. A 0600 file feeds that prompt.
omni_security_store() {
    account=$1
    service=$2
    value=$3
    if ! command -v python3 >/dev/null 2>&1; then
        echo "omni-secret: python3 is required to store a keychain item without showing it in ps" >&2
        return 1
    fi
    old_umask=$(umask)
    umask 077
    pwfile=$(mktemp) || return 1
    umask "$old_umask"
    printf '%s' "$value" > "$pwfile"
    chmod 600 "$pwfile" 2>/dev/null || true
    python3 - "$pwfile" "$account" "$service" << 'PY'
import os, sys, pty, select, time
pwfile, account, service = sys.argv[1:4]
with open(pwfile, "r") as fh:
    password = fh.read()
os.remove(pwfile)
argv = ["security", "add-generic-password", "-U", "-a", account, "-s", service, "-w"]
pid, fd = pty.fork()
if pid == 0:
    os.execvp(argv[0], argv)
blob = (password + "\n").encode()
sent = 0
end = time.time() + 5
while sent < 2 and time.time() < end:
    _, writable, _ = select.select([], [fd], [], 0.2)
    if writable:
        os.write(fd, blob)
        sent += 1
    readable, _, _ = select.select([fd], [], [], 0.05)
    if readable:
        try:
            os.read(fd, 4096)
        except OSError:
            break
os.waitpid(pid, 0)
PY
    rc=$?
    rm -f "$pwfile"
    return "$rc"
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
# Configuration: ~/.config/omni-term-ai/config
#   OMNI_LEFT_HARNESS=agy      # top-left Command Center pane
#   OMNI_RIGHT_HARNESS=grok    # top-right Command Center pane
# Parsed as literal KEY=VALUE assignments. Never sourced.
# ---------------------------------------------------------------------------

omni_config_path() {
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/omni-term-ai/config"
}

omni_config_key_ok() {
    case $1 in
    OMNI_LEFT_HARNESS | OMNI_RIGHT_HARNESS | OMNI_JUMPBOX | OMNI_FIM_ENGINE | OMNI_FIM_PROVIDER | OMNI_AZURE_ENDPOINT | OMNI_AZURE_DEPLOYMENT)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

# First character of $1. Empty if $1 is empty.
omni_config_first() {
    printf '%s' "${1%"${1#?}"}"
}

# Print $1 as a single-quoted literal. No trailing newline.
# Returns 1 if $1 contains a newline (those cannot round-trip in this file).
omni_config_quote() {
    _cq=$1
    case $_cq in
    *'
'*)
        echo "omni-term-ai: config values cannot contain newlines" >&2
        return 1
        ;;
    esac
    printf "'"
    while :; do
        case $_cq in
        *\'*)
            printf '%s' "${_cq%%\'*}"
            printf '%s' "'\\''"
            _cq=${_cq#*\'}
            ;;
        *)
            printf '%s' "$_cq"
            break
            ;;
        esac
    done
    printf "'"
}

# Literal value of the text after '='. Does not expand or execute.
# Prints the value and a newline. Returns 1 on broken quoting.
omni_config_parse_value() {
    _cv=$1
    _cf=$(omni_config_first "$_cv")
    case $_cf in
    \')
        _cv=${_cv#?}
        _co=
        while :; do
            if [ -z "$_cv" ]; then
                echo "omni-term-ai: unterminated single quote in config" >&2
                return 1
            fi
            _cc=$(omni_config_first "$_cv")
            _cv=${_cv#?}
            case $_cc in
            \')
                # Writer escapes an embedded quote as: '\''
                # The closer was just consumed, so the escape remains as \''
                _n1=$(omni_config_first "$_cv")
                if [ "$_n1" = \\ ]; then
                    _rest=${_cv#?}
                    _n2=$(omni_config_first "$_rest")
                    _rest2=${_rest#?}
                    _n3=$(omni_config_first "$_rest2")
                    if [ "$_n2" = "'" ] && [ "$_n3" = "'" ]; then
                        _co=${_co}\'
                        _cv=${_rest2#?}
                        continue
                    fi
                fi
                case $_cv in
                '' | [[:space:]]* | \#*)
                    printf '%s\n' "$_co"
                    return 0
                    ;;
                *)
                    echo "omni-term-ai: trailing junk after quoted config value" >&2
                    return 1
                    ;;
                esac
                ;;
            *)
                _co=${_co}${_cc}
                ;;
            esac
        done
        ;;
    \")
        _cv=${_cv#?}
        _co=
        while :; do
            if [ -z "$_cv" ]; then
                echo "omni-term-ai: unterminated double quote in config" >&2
                return 1
            fi
            _cc=$(omni_config_first "$_cv")
            _cv=${_cv#?}
            case $_cc in
            \\)
                if [ -z "$_cv" ]; then
                    echo "omni-term-ai: unterminated double quote in config" >&2
                    return 1
                fi
                _co=${_co}$(omni_config_first "$_cv")
                _cv=${_cv#?}
                ;;
            \")
                case $_cv in
                '' | [[:space:]]* | \#*)
                    printf '%s\n' "$_co"
                    return 0
                    ;;
                *)
                    echo "omni-term-ai: trailing junk after quoted config value" >&2
                    return 1
                    ;;
                esac
                ;;
            *)
                _co=${_co}${_cc}
                ;;
            esac
        done
        ;;
    *)
        # Legacy unquoted assignment. The remainder is literal text.
        printf '%s\n' "$_cv"
        ;;
    esac
}

omni_config_assign() {
    case $1 in
    OMNI_LEFT_HARNESS) OMNI_LEFT_HARNESS=$2 ;;
    OMNI_RIGHT_HARNESS) OMNI_RIGHT_HARNESS=$2 ;;
    OMNI_JUMPBOX) OMNI_JUMPBOX=$2 ;;
    OMNI_FIM_ENGINE) OMNI_FIM_ENGINE=$2 ;;
    OMNI_FIM_PROVIDER) OMNI_FIM_PROVIDER=$2 ;;
    OMNI_AZURE_ENDPOINT) OMNI_AZURE_ENDPOINT=$2 ;;
    OMNI_AZURE_DEPLOYMENT) OMNI_AZURE_DEPLOYMENT=$2 ;;
    *)
        return 1
        ;;
    esac
}

# Replace or append one allowlisted assignment. Copies every other line through.
omni_config_update() {
    _ukey=$1
    _uval=$2
    _ufile=$3
    omni_config_key_ok "$_ukey" || return 1
    _uquoted=$(omni_config_quote "$_uval") || return 1
    _udir=$(dirname "$_ufile")
    _utmp=$(mktemp "$_udir/config.XXXXXX") || return 1
    _ufound=0
    if [ -f "$_ufile" ]; then
        while IFS= read -r _uline || [ -n "$_uline" ]; do
            case $_uline in
            "$_ukey"=*)
                printf '%s=%s\n' "$_ukey" "$_uquoted"
                _ufound=1
                ;;
            *)
                printf '%s\n' "$_uline"
                ;;
            esac
        done < "$_ufile" > "$_utmp"
    else
        : > "$_utmp"
    fi
    if [ "$_ufound" -eq 0 ]; then
        printf '%s=%s\n' "$_ukey" "$_uquoted" >> "$_utmp"
    fi
    mv "$_utmp" "$_ufile"
    chmod 600 "$_ufile" 2>/dev/null || true
}

# Load the config file. Unknown keys and broken lines are skipped.
# Missing keys keep an existing value, or the historical default.
omni_load_config() {
    _lcfg=$(omni_config_path)
    if [ -f "$_lcfg" ]; then
        _lline=0
        while IFS= read -r _lrow || [ -n "$_lrow" ]; do
            _lline=$((_lline + 1))
            _ltrim=$_lrow
            while :; do
                case $_ltrim in
                [[:space:]]*) _ltrim=${_ltrim#?} ;;
                *) break ;;
                esac
            done
            case $_ltrim in
            '' | \#*) continue ;;
            esac
            case $_ltrim in
            *=*)
                _lkey=${_ltrim%%=*}
                _lrest=${_ltrim#*=}
                ;;
            *)
                echo "omni-term-ai: warning: $_lcfg:$_lline: ignored (not KEY=VALUE)" >&2
                continue
                ;;
            esac
            case $_lkey in
            *[[:space:]]* | '')
                echo "omni-term-ai: warning: $_lcfg:$_lline: ignored" >&2
                continue
                ;;
            esac
            if ! omni_config_key_ok "$_lkey"; then
                echo "omni-term-ai: warning: $_lcfg:$_lline: ignored unknown key $_lkey" >&2
                continue
            fi
            if ! _lval=$(omni_config_parse_value "$_lrest"); then
                echo "omni-term-ai: warning: $_lcfg:$_lline: could not parse $_lkey; skipping" >&2
                continue
            fi
            omni_config_assign "$_lkey" "$_lval"
        done < "$_lcfg"
    fi
    # Default only when a value is missing, never when it is invalid:
    # launch-ai-workspace reports invalid values so the user can fix their
    # config instead of silently getting a different harness.
    : "${OMNI_LEFT_HARNESS:=agy}"
    : "${OMNI_RIGHT_HARNESS:=grok}"
    : "${OMNI_JUMPBOX:=}"
    : "${OMNI_FIM_ENGINE:=native}"
    : "${OMNI_FIM_PROVIDER:=deepseek}"
    : "${OMNI_AZURE_ENDPOINT:=}"
    : "${OMNI_AZURE_DEPLOYMENT:=}"
    export OMNI_LEFT_HARNESS OMNI_RIGHT_HARNESS OMNI_JUMPBOX OMNI_FIM_ENGINE OMNI_FIM_PROVIDER
    export OMNI_AZURE_ENDPOINT OMNI_AZURE_DEPLOYMENT
}

omni_config_get() {
    case $1 in
    left) printf '%s\n' "$OMNI_LEFT_HARNESS" ;;
    right) printf '%s\n' "$OMNI_RIGHT_HARNESS" ;;
    jumpbox) printf '%s\n' "$OMNI_JUMPBOX" ;;
    fim) printf '%s\n' "$OMNI_FIM_ENGINE" ;;
    fim-provider) printf '%s\n' "$OMNI_FIM_PROVIDER" ;;
    azure-endpoint) printf '%s\n' "$OMNI_AZURE_ENDPOINT" ;;
    azure-deployment) printf '%s\n' "$OMNI_AZURE_DEPLOYMENT" ;;
    esac
}

# Remote script for launch-ai-workspace @target. Printed, never executed here.
# The target is embedded as a single-quoted literal. sshfs failure aborts
# (set -eu, no "|| echo"). Does not mount the jumpbox's own hostname.
omni_jumpbox_target_script() {
    _jt=$1
    case $_jt in
    '' | *'
'*)
        echo "omni-term-ai: invalid remote target" >&2
        return 1
        ;;
    esac
    _jq=$(omni_config_quote "$_jt") || return 1
    cat <<EOF
set -eu
target=$_jq
if ! command -v sshfs >/dev/null 2>&1; then
    echo "omni-term-ai: sshfs is required on the jumpbox for a remote target" >&2
    exit 1
fi
mnt="\$HOME/mnt/\$target"
mkdir -p -- "\$mnt"
if command -v mountpoint >/dev/null 2>&1 && mountpoint -q -- "\$mnt"; then
    :
else
    sshfs -- "\$target":/ "\$mnt"
fi
cd -- "\$mnt"
export OMNI_SKIP_JUMPBOX=1
export TERM="\$TERM"
exec launch-ai-workspace "\$target"
EOF
}

# ---------------------------------------------------------------------------
# Key injection: harness auth env vars, fetched from the OS secret store.
# A stored secret replaces the variable. A missing secret must not export an
# empty string: that masks keyring auth and ambient tokens. An already-empty
# variable is unset. A non-empty ambient value is left alone.
# ---------------------------------------------------------------------------

omni_assign_secret() {
    _an=$1
    _as=$2
    case $_an in
    XAI_API_KEY | DEEPSEEK_API_KEY | ANTHROPIC_API_KEY | OPENAI_API_KEY | GH_TOKEN | GITHUB_TOKEN | GEMINI_API_KEY | AZURE_OPENAI_API_KEY) ;;
    *)
        echo "omni-term-ai: refusing to assign $_an" >&2
        return 1
        ;;
    esac
    if [ -n "$_as" ]; then
        case $_an in
        XAI_API_KEY) XAI_API_KEY=$_as; export XAI_API_KEY ;;
        DEEPSEEK_API_KEY) DEEPSEEK_API_KEY=$_as; export DEEPSEEK_API_KEY ;;
        ANTHROPIC_API_KEY) ANTHROPIC_API_KEY=$_as; export ANTHROPIC_API_KEY ;;
        OPENAI_API_KEY) OPENAI_API_KEY=$_as; export OPENAI_API_KEY ;;
        GH_TOKEN) GH_TOKEN=$_as; export GH_TOKEN ;;
        GITHUB_TOKEN) GITHUB_TOKEN=$_as; export GITHUB_TOKEN ;;
        GEMINI_API_KEY) GEMINI_API_KEY=$_as; export GEMINI_API_KEY ;;
        AZURE_OPENAI_API_KEY) AZURE_OPENAI_API_KEY=$_as; export AZURE_OPENAI_API_KEY ;;
        esac
        return 0
    fi
    case $_an in
    XAI_API_KEY) if [ "${XAI_API_KEY+x}" = x ] && [ -z "$XAI_API_KEY" ]; then unset XAI_API_KEY; fi ;;
    DEEPSEEK_API_KEY) if [ "${DEEPSEEK_API_KEY+x}" = x ] && [ -z "$DEEPSEEK_API_KEY" ]; then unset DEEPSEEK_API_KEY; fi ;;
    ANTHROPIC_API_KEY) if [ "${ANTHROPIC_API_KEY+x}" = x ] && [ -z "$ANTHROPIC_API_KEY" ]; then unset ANTHROPIC_API_KEY; fi ;;
    OPENAI_API_KEY) if [ "${OPENAI_API_KEY+x}" = x ] && [ -z "$OPENAI_API_KEY" ]; then unset OPENAI_API_KEY; fi ;;
    GH_TOKEN) if [ "${GH_TOKEN+x}" = x ] && [ -z "$GH_TOKEN" ]; then unset GH_TOKEN; fi ;;
    GITHUB_TOKEN) if [ "${GITHUB_TOKEN+x}" = x ] && [ -z "$GITHUB_TOKEN" ]; then unset GITHUB_TOKEN; fi ;;
    GEMINI_API_KEY) if [ "${GEMINI_API_KEY+x}" = x ] && [ -z "$GEMINI_API_KEY" ]; then unset GEMINI_API_KEY; fi ;;
    AZURE_OPENAI_API_KEY) if [ "${AZURE_OPENAI_API_KEY+x}" = x ] && [ -z "$AZURE_OPENAI_API_KEY" ]; then unset AZURE_OPENAI_API_KEY; fi ;;
    esac
}

omni_export_harness_keys() {
    omni_assign_secret XAI_API_KEY "$(omni_secret_get xai)"
    omni_assign_secret DEEPSEEK_API_KEY "$(omni_secret_get deepseek)"
    omni_assign_secret ANTHROPIC_API_KEY "$(omni_secret_get anthropic)"
    omni_assign_secret OPENAI_API_KEY "$(omni_secret_get openai)"
    _gh=$(omni_secret_get github)
    omni_assign_secret GH_TOKEN "$_gh"
    omni_assign_secret GITHUB_TOKEN "$_gh"
    omni_assign_secret GEMINI_API_KEY "$(omni_secret_get gemini)"
    omni_assign_secret AZURE_OPENAI_API_KEY "$(omni_secret_get azure)"
}

# Copy a secret into the tmux session only when it has a value.
# An empty value is removed (set-environment -u) so a pane never inherits "".
omni_tmux_publish_one() {
    if [ -n "$2" ]; then
        omni_tmux set-environment -g "$1" "$2"
    else
        omni_tmux set-environment -g -u "$1" || true
    fi
}

omni_publish_tmux_secrets() {
    omni_tmux_publish_one XAI_API_KEY "${XAI_API_KEY:-}"
    omni_tmux_publish_one DEEPSEEK_API_KEY "${DEEPSEEK_API_KEY:-}"
    omni_tmux_publish_one ANTHROPIC_API_KEY "${ANTHROPIC_API_KEY:-}"
    omni_tmux_publish_one OPENAI_API_KEY "${OPENAI_API_KEY:-}"
    omni_tmux_publish_one GH_TOKEN "${GH_TOKEN:-}"
    omni_tmux_publish_one GITHUB_TOKEN "${GITHUB_TOKEN:-}"
    omni_tmux_publish_one GEMINI_API_KEY "${GEMINI_API_KEY:-}"
    omni_tmux_publish_one AZURE_OPENAI_API_KEY "${AZURE_OPENAI_API_KEY:-}"
    omni_tmux_publish_one AZURE_OPENAI_ENDPOINT "${AZURE_OPENAI_ENDPOINT:-}"
    omni_tmux_publish_one AZURE_OPENAI_DEPLOYMENT "${AZURE_OPENAI_DEPLOYMENT:-}"
}

# Config holds the Azure endpoint and deployment (not secrets). A non-empty
# config value wins. An empty config value leaves a non-empty ambient value.
omni_apply_azure_config() {
    if [ -n "${OMNI_AZURE_ENDPOINT:-}" ]; then
        AZURE_OPENAI_ENDPOINT=$OMNI_AZURE_ENDPOINT
        export AZURE_OPENAI_ENDPOINT
    fi
    if [ -n "${OMNI_AZURE_DEPLOYMENT:-}" ]; then
        AZURE_OPENAI_DEPLOYMENT=$OMNI_AZURE_DEPLOYMENT
        export AZURE_OPENAI_DEPLOYMENT
    fi
}
