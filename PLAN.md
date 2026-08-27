# Omni Term AI - Dual Tab Neovim Plan (RDAP)

## 2. Scope of Work
**Primary Goal**: Convert the tmux workspace into a dual-tab architecture (Tab 1: Command Center, Tab 2: Full-screen Neovim) with an instant hotkey toggle, and provide a fully configured Neovim setup.
**Non-Goals**: We are not writing a custom Neovim plugin from scratch. We are not setting up multiple popups.
**Success Criteria**: 
- `launch-ai-workspace` creates two tmux windows.
- `Ctrl-b e` toggles instantly between the two windows.
- Neovim is configured with a file explorer (e.g., neo-tree or nvim-tree) and modern defaults.
**Constraints**: Tmux 3.2+, Neovim 0.9.5+.
**Risks**: Tmux window switching bindings might conflict. Neovim kickstart might require external dependencies like `ripgrep` or `gcc` (will mitigate by checking system).

## 3. Comprehensive Plan

### Phase 1 - Research & Discovery
- **Milestone 1.1**: Verify dependencies (`ripgrep`, `gcc`, `unzip` for Neovim plugins).
  - Task 1: Check dependencies.
- **Milestone 1.2**: Research Tmux window toggling.
  - Task 1: Find the command to switch between exactly two windows. (e.g. `tmux select-window -t :=1` or `tmux last-window`).
  - Task 2: Synthesize findings into `RESEARCH.md`.

### Phase 2 - Architecture
- **Milestone 2.1**: Update script logic.
  - Task 1: Design `launch-ai-workspace` to create a second window and map `Ctrl-b e` to `last-window` (since it switches between the two).

### Phase 3 - Implementation
- **Milestone 3.1**: Deploy Neovim Config.
  - Task 1: Clone or write a kickstart-based `init.lua` into `nvim-config/init.lua` in the repo.
  - Task 2: Symlink it to `~/.config/nvim`.
- **Milestone 3.2**: Modify `launch-ai-workspace`.
  - Task 1: Update the bash script to spawn `ai-session:1` (Command Center) and `ai-session:2` (Editor).
  - Task 2: Remove Neovim from the bottom pane of Tab 1.
- **Milestone 3.3**: Update `tmux.conf`.
  - Task 1: Map `bind e last-window` or custom select window in `tmux.conf`.

### Final Phase - Verification & Polish
- **Milestone 4.1**: Test the environment.
  - Task 1: Run the launcher and verify dual tabs.
  - Task 2: Commit, PR, merge, clean up worktree.
