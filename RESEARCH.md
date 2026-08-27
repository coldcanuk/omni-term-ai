# Research: Dual Tab Tmux & Neovim

1. **Neovim Dependencies**: 
   - Found `rg`, `gcc`, `unzip`, `git` are installed on the system.
   - Neovim 0.9.5 is present. We can safely deploy a `lazy.nvim` based configuration.
   - We will use a single-file `init.lua` (Kickstart style) tailored for AI workspace.

2. **Tmux Window Toggling**:
   - The command `tmux last-window` switches to the previously active window.
   - If we have exactly 2 windows (Command Center and Editor), `last-window` acts as a perfect boolean toggle.
   - We will bind `Ctrl-b e` to `last-window`.

3. **Tmux Setup Script**:
   - `tmux new-window -t $SESSION_NAME:2 -n "Editor" "nvim"` will spawn the second tab.
   - We will ensure Tab 1 is named "Command Center".
