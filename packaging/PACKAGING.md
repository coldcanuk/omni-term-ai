# Packaging architecture

Install API: `make install PREFIX=<prefix> DESTDIR=<stage>`.

Default `PREFIX` is `/usr/local`. Debian/RPM packages use `PREFIX=/usr`.
Homebrew uses the formula prefix (Cellar). OpenBSD ports use `/usr/local`.

## Layout

```
$(PREFIX)/bin/launch-ai-workspace
$(PREFIX)/bin/omni-exec
$(PREFIX)/bin/omni-secret
$(PREFIX)/bin/tmux-toggle-scratch
$(PREFIX)/share/omni-term-ai/lib/omni.sh
$(PREFIX)/share/omni-term-ai/tmux.conf
$(PREFIX)/share/omni-term-ai/nvim-config/
$(PREFIX)/share/applications/ai-workspace.desktop
$(PREFIX)/share/icons/hicolor/scalable/apps/ai-workspace.svg
$(PREFIX)/share/man/man1/launch-ai-workspace.1
$(PREFIX)/share/doc/omni-term-ai/README.md
$(PREFIX)/share/doc/omni-term-ai/LICENSE
```

## Runtime

- Share directory: `OMNI_TERM_AI_HOME`, else substituted `@OMNI_HOME@`, else resolve `$0`.
- Neovim: `NVIM_APPNAME=omni-term-ai` (does not replace `~/.config/nvim`).
- Tmux: socket `omni-term-ai` and packaged `tmux.conf`.
- Secrets: `omni-secret` → secret-tool (Linux), `security` (macOS), `pass`, or `0600` files.

## Fronts

| OS | Command |
| --- | --- |
| Ubuntu/Debian | `make deb` → `dist/omni-term-ai_*_all.deb` |
| Fedora/RHEL | `make rpm` (needs `rpmbuild`) |
| macOS | `brew tap coldcanuk/omni-term-ai https://github.com/coldcanuk/omni-term-ai` then `brew install --HEAD omni-term-ai` |
| OpenBSD | port in `packaging/openbsd/` or `make install PREFIX=/usr/local` |
| Any | `./install.sh` or `make install PREFIX="$HOME/.local"` |
