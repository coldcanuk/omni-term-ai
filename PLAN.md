# Scope of Work

**Primary Goal**: Open-source the terminal AI workspace setup in `/opt/repo/omni-term-ai` on GitHub. Use GPLv3. Ensure API keys are fetched on the fly via `secret-tool` rather than using global environment variables in `.bashrc`.
**Non-Goals**: Full LLM FIM completion client implementation (this phase is strictly repository setup, architecture, and secure dynamic credential wiring).
**Success Criteria**: 
  - Repo initialized at `/opt/repo/omni-term-ai`.
  - Pushed to GitHub under `coldcanuk/omni-term-ai`.
  - GPLv3 `LICENSE` and valid `.gitignore` present.
  - `README.md` explicitly documents how to use `secret-tool` to avoid cleartext keys.
  - `~/.bashrc` is verified to NOT contain any global key exports.
  - Scripts dynamically fetch keys via `secret-tool lookup` only when needed.
**Constraints**: `/opt/repo` local directory. GitHub CLI (`gh`). RDAP methodology.
**Top Risks**: 
  - Accidental key exposure (Mitigation: Strict `.gitignore`, code review of wrapper scripts).

# RDAP Plan

## Phase 0: Environment & Isolation Setup
- **M0.1**: Initialize Repo
  - **Task 1**: `mkdir -p /opt/repo/omni-term-ai && cd /opt/repo/omni-term-ai && git init`
  - **Task 2**: Create baseline files (`.gitignore`, `LICENSE`, `README.md`)
  - **Task 3**: Commit and configure GitHub repository via `gh`.
  - **Task 4**: Create git worktree `gb/dynamic-secrets`.

## Phase 1: Research & Discovery
- **M1.1**: Security & Authentication Audit.
  - **Task 1**: Verify `gh auth status` confirms `coldcanuk` access.
  - **Task 2**: Audit `~/.bashrc` to ensure `XAI_API_KEY` and `DEEPSEEK_API_KEY` global exports are permanently removed.
  - **Task 3**: Synthesize `RESEARCH.md` and confirm the dynamic fetching strategy.

## Phase 2: Define / Architecture
- **M2.1**: Define the dynamic secret fetching wrapper.
  - **Task 1**: Outline the architecture for an on-the-fly execution wrapper that prevents credential leakage into child process environments longer than necessary.

## Phase 3: Implementation
- **M3.1**: Build dynamic key fetcher.
  - **Task 1**: Write `omni-exec.sh` that securely wraps AI commands and injects credentials ephemerally.
  - **Task 2**: Add the customized `launch-ai-workspace` and `tmux.conf` configs into the repository.

## Phase 4: Verification, Polish, Integration & Cleanup
- **M4.1**: Finalize & Merge.
  - **Task 1**: Verify script syntax and `.gitignore`.
  - **Task 2**: Merge worktree into main, push to GitHub.
  - **Task 3**: Remove worktree.
