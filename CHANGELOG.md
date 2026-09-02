# Changelog

## 0.2.4
- Fix crash on launch caused by broken config symlink (`~/.config/omni-term-ai`) from legacy installations
- Refactor Neovim config provisioning to link individual files instead of full directory

## 0.2.0

- Configurable Command Center harnesses: `omni-config` (list/get/set/wizard)
  selects any of grok, agy, copilot, claude, codex, deepseek for the
  top-left and top-right panes (defaults: agy left, grok right)
- `launch-ai-workspace` validates harness binaries and prints install hints;
  harness names shown in pane titles (tmux >= 3.2)
- `omni-secret` / `omni-exec` support xai, deepseek, anthropic, openai,
  github, gemini keys; injected into the tmux session environment
- DeepSeek Fill-In-The-Middle (FIM) ghost-text completion in the Neovim
  Editor (`nvim-config/lua/omni_fim.lua`, `<Tab>` accept, `<C-e>` dismiss)
- macOS Homebrew docs: `brew trust` step for Homebrew 6.0+ tap trust
- New `man/omni-config.1`; updated launcher man page, desktop file,
  deb/rpm descriptions

## 0.1.0

- POSIX `make install` layout (`PREFIX` / `DESTDIR`)
- Debian `.deb` (`make deb`) and RPM spec (`make rpm`)
- Homebrew formula (`Formula/omni-term-ai.rb`)
- OpenBSD port skeleton under `packaging/openbsd/`
- `omni-secret` backends: secret-tool, macOS Keychain, pass, 0600 files
- Remove hardcoded `/opt/repo` and `/home/chuck` install paths
