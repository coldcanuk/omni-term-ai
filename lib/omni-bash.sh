#!/bin/bash
# Omni Term AI - Bash Integration
# Source this file in your ~/.bashrc to get shell completion
# and to export API keys for Neovim AI integration outside of tmux.
# This does not set NVIM_APPNAME unless OMNI_USE_NVIM_CONFIG=1.

# True when the configured FIM provider has a key to call.
omni_fim_should_bind() {
    case ${OMNI_FIM_PROVIDER:-deepseek} in
        openai) [ -n "${OPENAI_API_KEY:-}" ] ;;
        azure) [ -n "${AZURE_OPENAI_API_KEY:-}" ] ;;
        deepseek) [ -n "${DEEPSEEK_API_KEY:-}" ] ;;
        *) return 1 ;;
    esac
}

# Determine installation directory if not set
if [ -z "${OMNI_TERM_AI_HOME:-}" ]; then
    if [ -f "@OMNI_HOME@/lib/omni.sh" ]; then
        export OMNI_TERM_AI_HOME="@OMNI_HOME@"
    elif [ -f "/usr/local/share/omni-term-ai/lib/omni.sh" ]; then
        export OMNI_TERM_AI_HOME="/usr/local/share/omni-term-ai"
    elif [ -f "$HOME/.local/share/omni-term-ai/lib/omni.sh" ]; then
        export OMNI_TERM_AI_HOME="$HOME/.local/share/omni-term-ai"
    fi
fi

if [ -n "${OMNI_TERM_AI_HOME:-}" ] && [ -f "$OMNI_TERM_AI_HOME/lib/omni.sh" ]; then
    . "$OMNI_TERM_AI_HOME/lib/omni.sh"
    omni_load_config
    omni_export_harness_keys

    # Bind Ctrl-F when the configured FIM provider has a key.
    if omni_fim_should_bind; then
        . "$OMNI_TERM_AI_HOME/lib/deepseek-completion.bash"
    fi
    
    # Ctrl-F does not retarget nvim. Set OMNI_USE_NVIM_CONFIG=1 to ask.
    if [ "${OMNI_USE_NVIM_CONFIG:-}" = 1 ]; then
        if [ -z "${NVIM_APPNAME:-}" ]; then
            export NVIM_APPNAME="omni-term-ai"
        fi
        if [ "$NVIM_APPNAME" = "omni-term-ai" ]; then
            omni_ensure_nvim_config
        fi
    fi
fi
