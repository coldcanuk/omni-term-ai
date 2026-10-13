# Changelog

## 0.3.0

- Config is parsed as literal assignments, not sourced (BUG-01).
- A no-arg launch with a jumpbox SSHes there instead of sshfs-mounting the jumpbox itself. A remote `@target` is one quoted sshfs argument, and a failed mount aborts (BUG-02).
- A missing secret no longer replaces an ambient token with an empty value (BUG-03).
- Azure FIM endpoint, deployment, and key reach the tmux session. A missing key is unset, not planted empty (BUG-04).
- Scratchpad and panic stay on the workspace tmux socket. The audit claim was wrong; a regression test covers it (BUG-05).
- First launch runs the sibling `omni-config` before any `PATH` lookup (BUG-06).
- FIM provider is explicit (`deepseek`, `openai`, or `azure`). An OpenAI key no longer silently wins (BUG-07).
- Bash completion inserts the picked choice and does not `eval` model text (BUG-08).
- A stale FIM response does not paint, and the request payload is removed (BUG-09).
- Uninstall removes every shipped man page. Pages document jumpbox, FIM, and Azure (BUG-10).
- `install.sh --deps` covers Arch, Omarchy, and FreeBSD (BUG-11).
- Agent cleanup starts from this clone, not `/opt/repo` (BUG-12).
- A failed gh-pages checkout does not publish over the existing site (BUG-13).
- `make test` fails if the bash libs are dropped from the install (IMP-01).
- Apt and rpm repositories are signed. Install without `trusted=yes` or `gpgcheck=0` (IMP-02).
- Packages require curl. python3 and sshfs stay optional. The bashrc snippet uses `omni-config home` (IMP-03).
- API keys stay off the command line. Old secret-tool items still resolve (IMP-04).
- This changelog covers the features that 0.2.x shipped without notes (IMP-05).

## 0.2.5
- Fix crash on launch caused by broken config symlink (`~/.config/omni-term-ai`) from legacy installations
- Refactor Neovim config provisioning to link individual files instead of full directory
- Undocumented features from this release are covered by 0.3.0.

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
