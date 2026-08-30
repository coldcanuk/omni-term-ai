#!/bin/bash
# Omni Term AI - Bash Integration
# Source this file in your ~/.bashrc to get DeepSeek shell completion
# and to export API keys for Neovim AI integration outside of tmux.

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
    omni_export_harness_keys
    
    # Enable DeepSeek Bash Completion
    if [ -n "$DEEPSEEK_API_KEY" ]; then
        . "$OMNI_TERM_AI_HOME/lib/deepseek-completion.bash"
    fi
    
    # Point Neovim to our config if NVIM_APPNAME is not already set
    if [ -z "${NVIM_APPNAME:-}" ]; then
        export NVIM_APPNAME="omni-term-ai"
        omni_ensure_nvim_config
    fi
fi
