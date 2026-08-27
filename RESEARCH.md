# Phase 1: Security Audit & Strategy

## Findings
1. **GitHub Auth**: User `coldcanuk` is successfully authenticated via `gh` with `repo` scopes.
2. **Bashrc Cleanliness**: All traces of `XAI_API_KEY` and `DEEPSEEK_API_KEY` have been stripped from `~/.bashrc`. The system is now secure against global process leaking.
3. **Dynamic Fetching Feasibility**: 
   - A wrapper script (e.g. `omni-exec.sh`) can dynamically call `secret-tool lookup` and pass the credential into the environment of a single, ephemeral child process.
   - Example architecture: `XAI_API_KEY=$(secret-tool lookup api xai) my-ai-command`
   - This ensures the key exists *only* in the memory of the specific command executing the AI request, rather than polluting the global interactive shell.

## Next Steps (Phase 2 & 3)
Build the `omni-exec.sh` wrapper, which will wrap AI terminal scripts. Ensure `.gitignore` ignores any accidentally generated local `.env` files.
