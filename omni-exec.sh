#!/usr/bin/env bash
# Omni-Exec: Securely fetches API keys on the fly for a single command.
# Usage: ./omni-exec.sh <command> [args...]

if [ $# -eq 0 ]; then
    echo "Usage: omni-exec.sh <command>"
    exit 1
fi

# Fetch keys ephemerally
XAI_KEY=$(secret-tool lookup api xai 2>/dev/null)
DEEPSEEK_KEY=$(secret-tool lookup api deepseek 2>/dev/null)

# Run the command with keys injected into its environment
env XAI_API_KEY="$XAI_KEY" DEEPSEEK_API_KEY="$DEEPSEEK_KEY" "$@"
