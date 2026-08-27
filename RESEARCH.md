# Research: Packaging Omni Term AI for Ubuntu, Debian, Red Hat, OpenBSD, and macOS

**Date of search:** 2026-08-27  
**Methodology:** Research-Driven Adaptive Planning (RDAP) — Double Diamond Discover/Define plus Spiral risk-driven research.  
**Research question:** How should this repository (shell scripts + tmux/Neovim config, GPLv3, no compiled language runtime of its own) be packaged so users on Ubuntu, Debian, Red Hat-family Linux, OpenBSD, and macOS can install it with the native tools they already trust?

## Abstract

Omni Term AI is an architecture-independent collection of POSIX-friendly scripts and configuration files. Native installability therefore means a single `PREFIX`/`DESTDIR` install layout consumed by five packaging fronts: `.deb` (Ubuntu/Debian), `.rpm` (Fedora/RHEL/CentOS Stream), an OpenBSD port skeleton (`NO_BUILD`, `PKG_ARCH=*`), a Homebrew formula/tap (macOS), and a source `Makefile` plus `install.sh` as the lowest common denominator. Hardcoded paths (`/opt/repo/omni-term-ai`, `/home/chuck/.local/bin`) and Linux-only `secret-tool` are the two blockers. Official distro inclusion (Debian NEW, Homebrew/core, OpenBSD CVS ports) is out of scope for the first release; GitHub Releases plus a Homebrew tap plus an in-tree OpenBSD port are sufficient.

## 1. What we are packaging

Inspected tree on `main` (commit `75e3661`):

| Artifact | Role |
| --- | --- |
| `launch-ai-workspace` | Creates/attaches a dual-window tmux session |
| `omni-exec.sh` | Injects API keys into a child process environment |
| `tmux-toggle-scratch` | Tmux popup helper |
| `tmux.conf` | Bindings (`prefix+e`, scratch, editor reset) |
| `nvim-config/` | lazy.nvim config (requires git, a C compiler, ripgrep, unzip) |
| `ai-workspace.desktop`, `brain.svg` | Linux desktop launcher + icon |
| `LICENSE` | GNU GPLv3 |

Runtime peers **not** shipped here: `tmux`, `nvim`, `agy`, `grok`. The launcher sends `agy` and `grok` to panes; missing binaries should not fail package install.

Blockers for packaging:

1. `launch-ai-workspace` always symlinks `~/.config/nvim` to `/opt/repo/omni-term-ai/nvim-config`.
2. `ai-workspace.desktop` Exec path is `/home/chuck/.local/bin/launch-ai-workspace`.
3. `omni-exec.sh` calls `secret-tool`, which is GNOME Secret Service / libsecret (Linux). macOS uses `security`; OpenBSD has neither.

## 2. Search strategy

Tools: `web_search`, `web_fetch`, local `command -v` (packaging toolchain survey).

Queries covered: nFPM vs fpm vs `dpkg-deb`; Homebrew taps and Formula Cookbook; OpenBSD ports (`NO_BUILD`, `INSTALL_SCRIPT`, `PKG_ARCH=*`); Debian Policy on scripts and `/usr/share/<pkg>`; Fedora package names (`neovim`, `ripgrep`, `libsecret` providing `secret-tool`); macOS `security find-generic-password`.

Inclusion: official docs (Debian Policy, Homebrew Formula Cookbook, OpenBSD Porter's Handbook / ports FAQ, nFPM configuration, Apple `security` CLI). Exclusion: unpaid third-party “submit your app to the App Store” packaging, Windows/MSIX.

## 3. Findings by theme

### 3.1 One install layout, many packagers

Debian Policy and the FHS put architecture-independent program data in `/usr/share/<package>` and user-facing commands in `/usr/bin` without a language suffix (`omni-exec`, not `omni-exec.sh`). RPM and OpenBSD (`/usr/local`) use the same split. Homebrew Cellar layout is `#{prefix}/bin` and `#{prefix}/share/omni-term-ai`; relative `../share/omni-term-ai` from a resolved (symlink-followed) bindir works for `/usr`, `/usr/local`, and Cellar.

**Decision:** A POSIX `Makefile` with `PREFIX` (default `/usr/local`) and `DESTDIR` is the single source of truth. `.deb`, `.rpm`, Homebrew `def install`, and the OpenBSD `do-install` all invoke `make install`.

nFPM can emit deb+rpm from one YAML and is the usual CI choice when a Go binary is already in the pipeline. This project has no Go build. Local environment has `dpkg-deb` and no `nfpm`/`rpmbuild`. **Decision:** `make deb` via staged `DESTDIR` + `dpkg-deb` (verifiable here). `make rpm` via a spec file + `rpmbuild` when present, plus a GitHub Actions Fedora job. Skip a mandatory nFPM dependency.

### 3.2 Ubuntu and Debian (`.deb`)

Debian Policy §10.4: scripts on PATH must have a `#!` line; do not install `*.sh` names. Shared data belongs in `/usr/share/omni-term-ai`. Package is `Architecture: all`.

Dependencies (Debian/Ubuntu names):

| Need | Package |
| --- | --- |
| tmux ≥ 3.2 | `tmux` |
| Neovim ≥ 0.9.5 | `neovim` |
| git (lazy.nvim) | `git` |
| Treesitter / fzf-native | `gcc`, `make` (or `build-essential`) |
| Telescope grep | `ripgrep` |
| plugin archives | `unzip` |
| `secret-tool` | `libsecret-tools` |

A custom PPA or full `debian/` source package (quilt, changelog, lintian) is not required for GitHub Release `.deb` files. `dpkg-deb --root-owner-group --build` on Ubuntu 24.04 / Pop!_OS 24.04 is enough.

Desktop file: `Exec=launch-ai-workspace` (must be on PATH after install). Icon in `hicolor/scalable/apps`.

### 3.3 Red Hat family (`.rpm`)

Fedora package names: `neovim`, `tmux`, `git`, `gcc`, `make`, `ripgrep`, `unzip`. `secret-tool` lives in the `libsecret` RPM (`/usr/bin/secret-tool`), not a `libsecret-tools` package.

BuildArch: `noarch`. Spec `%install` calls the same Makefile. RHEL/EPEL Neovim versions lag Fedora (EPEL 8/9 historically shipped 0.8.x); document a minimum of 0.9.5 and let RPM `Requires: neovim` be unversioned if older distros cannot satisfy `>= 0.9.5`.

### 3.4 macOS (Homebrew)

Homebrew/core will not accept a head-only, untagged, personal workspace config. A **tap** is the supported path:

```
brew install coldcanuk/omni-term-ai/omni-term-ai
```

Homebrew clones `https://github.com/<user>/homebrew-<tap>`. A tap of *this* repository also works:

```
brew tap coldcanuk/omni-term-ai https://github.com/coldcanuk/omni-term-ai
```

if a `Formula/` directory exists at the repo root. Formula Cookbook: `bin.install`, `depends_on "neovim"`, `head "…git", branch: "main"`, `license "GPL-3.0-or-later"` (SPDX; DFSG-compatible). A `test do` block should check more than `--version`.

macOS has no libsecret. Store/fetch API keys with:

```
security add-generic-password -a "$USER" -s "omni-term-ai.xai" -w …
security find-generic-password -a "$USER" -s "omni-term-ai.xai" -w
```

Desktop `.desktop` files are unused on macOS; caveats should tell users to run `launch-ai-workspace` from Terminal.app or iTerm.

### 3.5 OpenBSD (ports + `pkg_add`)

Official binary packages come only from the OpenBSD ports tree (CVS, maintainer OK, `portcheck`). First release cannot land in the official tree; we ship a **port skeleton** under `packaging/openbsd/` for `/usr/ports/mystuff/sysutils/omni-term-ai`.

Relevant ports knobs (Porter's Handbook, undeadly NO_BUILD example):

- `NO_BUILD=Yes` — scripts only
- `PKG_ARCH=*` — all architectures
- `do-install:` with `INSTALL_SCRIPT` / our Makefile
- `PERMIT_PACKAGE=Yes` (GPLv3+)
- `RUN_DEPENDS=editors/neovim devel/git textproc/ripgrep`

tmux and unzip are in OpenBSD **base**. There is no `secret-tool`. Practical secret backends: `pass` (`security/password-store`) or a `0600` file under `~/.config/omni-term-ai/secrets/`. bash is **not** in base (`lang/bash`); scripts must be POSIX `/bin/sh` (OpenBSD pdksh-compatible).

End users who do not want a port can `make install PREFIX=/usr/local` after installing `neovim`, `git`, and `ripgrep` with `pkg_add`.

### 3.6 Neovim config must not clobber `~/.config/nvim`

Neovim supports `NVIM_APPNAME`. Setting `NVIM_APPNAME=omni-term-ai` uses `~/.config/omni-term-ai` and `~/.local/share/omni-term-ai`, leaving the user's default Neovim config alone. First launch can symlink that directory to the packaged `nvim-config` if the user path does not exist.

Tmux `-f` is ignored if a server is already running. A dedicated socket (`tmux -L omni-term-ai`) isolates the packaged config from the user's default tmux server.

### 3.7 Toolchain on this builder

Pop!_OS 24.04: `dpkg-deb` present; `rpmbuild`, `nfpm`, `fpm`, `brew`, Docker/Podman absent. Deb construction and DESTDIR layout tests are mandatory locally. RPM and Homebrew are specified and CI/formula-audit-able, not fully installed here.

## 4. Alternatives considered

| Approach | Why not (for v0.1) |
| --- | --- |
| nFPM-only | Extra binary; `dpkg-deb` already here |
| Snap / Flatpak | Isolates tmux/nvim poorly; overkill for scripts |
| curl \| sh as the only install | Works, but not “Ubuntu/Debian/Red Hat/OpenBSD/macOS packaging” |
| Homebrew/core submission | Needs a stable tarball, bottles, and core review |
| Official OpenBSD port commit | Requires a ports@ OK and CVS developer |
| GNU `install -D` / `readlink -f` | Breaks OpenBSD and older macOS |
| Keep bash shebangs | OpenBSD base has no bash |

## 5. Updated risk register

| Risk | Mitigation |
| --- | --- |
| Hardcoded paths survive | Resolver in lib; DESTDIR test asserts no `/opt/repo` or `/home/chuck` |
| secret-tool missing on macOS/OpenBSD | `omni-secret` backends: secret-tool, security, pass, file |
| Official repos never accept us | GitHub Releases + tap + mystuff port + `make install` |
| Homebrew formula SHA of `main.tar.gz` rots | `head`-only formula until a `v*` tag |
| rpmbuild absent locally | Spec + Actions Fedora job; `make rpm` errors clearly |
| User's nvim/tmux configs overwritten | `NVIM_APPNAME` + `tmux -L omni-term-ai` |
| OpenBSD pdksh vs bashisms | POSIX `#!/bin/sh`, no `[[`, no `&>` |

## 6. Conclusion (packaging architecture)

1. POSIX Makefile (`PREFIX`/`DESTDIR`) is the install API.
2. Scripts locate `$PREFIX/share/omni-term-ai` by resolving `$0` and honor `OMNI_TERM_AI_HOME`.
3. Secrets go through `omni-secret` with OS-native backends.
4. Ubuntu/Debian: `make deb` → `omni-term-ai_${VERSION}_all.deb`.
5. Red Hat: `packaging/rpm/omni-term-ai.spec` + `make rpm`.
6. macOS: `Formula/omni-term-ai.rb` tap (`brew install coldcanuk/omni-term-ai/omni-term-ai`).
7. OpenBSD: in-tree port skeleton + `make install PREFIX=/usr/local`.
8. `install.sh` detects the OS, installs distro packages, then `make install`.

## References

1. Debian Policy Manual, Ch. 10 Files (scripts, `/usr/share`). https://www.debian.org/doc/debian-policy/ch-files.html
2. nFPM configuration reference. https://nfpm.goreleaser.com/docs/configuration/
3. nFPM tips (pre/post scripts, lintian). https://nfpm.goreleaser.com/docs/tips/
4. Homebrew Formula Cookbook. https://docs.brew.sh/Formula-Cookbook
5. Homebrew: How to Create and Maintain a Tap. https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap
6. OpenBSD Ports FAQ — Working with Ports. https://www.openbsd.org/faq/ports/ports.html
7. OpenBSD Porting Guide. https://www.openbsd.org/faq/ports/guide.html
8. OpenBSD `bsd.port.mk(5)`. https://man.openbsd.org/bsd.port.mk.5
9. Pachl, C. “How to Create an OpenBSD Port and Package” (NO_BUILD script example). https://undeadly.org/cgi?action=article%3Bsid=20080318060000
10. Debian package `libsecret-tools`. https://packages.debian.org/sid/libsecret-tools
11. Fedora `libsecret` files (`/usr/bin/secret-tool`). https://packages.fedoraproject.org/pkgs/libsecret/libsecret/fedora-41.html
12. Fedora `neovim` / `ripgrep` package names. https://packages.fedoraproject.org/pkgs/neovim
13. macOS `security` password commands. https://ss64.com/mac/security-password.html
14. Apple Keychain items documentation. https://developer.apple.com/documentation/security/keychain-items
15. GNU GPLv3. `LICENSE` in this repository.

---

# 7. Research: Multi-harness shell assistants, Homebrew tap trust, DeepSeek FIM (2026-08-27)

**Date of search:** 2026-08-27
**Methodology:** RDAP Spiral risk-driven research; every claim verified live against official docs, the npm registry, the GitHub API, and `docs.brew.sh` (no training-data guesses).
**Research question:** Which shell AI assistants can the Command Center panes launch, how does each authenticate, how do macOS Homebrew users trust and install from this repo, and how does the DeepSeek API key power Fill-In-The-Middle (FIM) completion in Neovim?

## 7.1 Harness registry (verified 2026-08-27)

| Harness | Binary | Install | Launch | Auth env var(s) |
| --- | --- | --- | --- | --- |
| grok (xAI Grok Build) | `grok` | `curl -fsSL https://x.ai/cli/install.sh \| bash` | `grok` | `XAI_API_KEY` (fallback; browser OAuth primary) |
| agy (Google Antigravity) | `agy` | `curl -fsSL https://antigravity.google/cli/install.sh \| bash` | `agy` | Google sign-in; optional `GEMINI_API_KEY` / `GOOGLE_API_KEY` |
| copilot (GitHub copilot-cli) | `copilot` | `brew install copilot-cli` or `curl -fsSL https://gh.io/copilot-install \| bash` | `copilot` | `/login`; PAT via `GH_TOKEN` / `GITHUB_TOKEN` |
| claude code | `claude` | `npm install -g @anthropic-ai/claude-code` | `claude` | `ANTHROPIC_API_KEY` (or `/login`) |
| codex (OpenAI) | `codex` | `npm install -g @openai/codex` | `codex` | `OPENAI_API_KEY` (or `codex login`) |
| deepseek (DeepSeek Harness) | `dsh` | `npm install -g @deepseek-ai/dsh` (or `npx @deepseek-ai/dsh`) | `dsh web --no-open` | `DEEPSEEK_API_KEY` |

Notes:
- `grok-code` is obsolete; the current product is **Grok Build** (repo `xai-org/grok-build`), binary `grok`. There is no `GROK_API_KEY`; the documented API-key env var is `XAI_API_KEY`.
- `agy` is **Google's Antigravity CLI** (npm package `agy` is an empty placeholder). Google account sign-in is the primary auth; no `AGY_API_KEY` exists.
- `gh copilot` (extension repo `github/gh-copilot`) was deprecated 2025-10-25 in favor of the standalone **`copilot`** CLI (`github/copilot-cli`, `brew install copilot-cli`).
- `claude-code` npm latest verified: `@anthropic-ai/claude-code@2.1.247`, bin `claude`.
- `codex` npm latest verified: `@openai/codex@0.150.1`, bin `codex`.
- DeepSeek Harness: npm `@deepseek-ai/dsh@0.1.1-rc.2`, repo `deepseek-ai/deepseek-harness` (MIT, developer preview). `dsh web` starts a web UI at `http://127.0.0.1:3080`; `--no-open` suits a tmux pane. One-shot mode: `dsh --profile headless "job"`.

## 7.2 Homebrew tap trust (`brew trust`) — verified from docs.brew.sh

- Homebrew **6.0.0** (released 2026-06-11) introduced **tap trust**: non-official taps must be explicitly trusted before Homebrew evaluates their Ruby.
- `brew trust` exists (manpage): `brew trust [options] [target …]` with `--tap`, `--formula`, `--cask`, `--command`, `--json=v1`. Companion: `brew untrust`. Trust store: `${XDG_CONFIG_HOME}/homebrew/trust.json` (or `~/.homebrew/trust.json`).
- `HOMEBREW_REQUIRE_TAP_TRUST` defaults to true; `HOMEBREW_NO_REQUIRE_TAP_TRUST` is the (not recommended, to-be-removed) opt-out.
- For this repo the copy-paste sequence is:
  ```sh
  brew tap coldcanuk/omni-term-ai
  brew trust --formula coldcanuk/omni-term-ai/omni-term-ai   # scoped trust (recommended)
  # or: brew trust coldcanuk/omni-term-ai                    # whole tap
  brew install omni-term-ai
  ```
  A fully-qualified `brew install coldcanuk/omni-term-ai/omni-term-ai` also works (trusts just that item). Until a tagged release exists, the formula is head-only, so use `brew install --HEAD coldcanuk/omni-term-ai/omni-term-ai` or the in-tree `brew install --HEAD --formula ./Formula/omni-term-ai.rb` fallback for older Homebrew.
- Sources: https://docs.brew.sh/Manpage , https://docs.brew.sh/Tap-Trust , https://brew.sh/2026/06/11/homebrew-6.0.0/

## 7.3 DeepSeek FIM — verified from api-docs.deepseek.com/guides/fim_completion

- Endpoint: OpenAI-compatible `POST https://api.deepseek.com/beta/completions` (the `/beta` base URL enables the feature).
- Request: `{ "model": "deepseek-v4-pro", "prompt": "<prefix>", "suffix": "<suffix>", "max_tokens": 128 }` (suffix optional).
- Response: standard completions → `choices[0].text`. Max FIM output: 4K tokens.
- Auth: `Authorization: Bearer ${DEEPSEEK_API_KEY}`.
- Env var convention confirmed: `DEEPSEEK_API_KEY` (platform.deepseek.com).

## 7.4 Neovim FIM plugin decision

Surveyed `tzachar/cmp-ai` (277★, last push 2026-02), `magicalne/fim.nvim`, `aliou/nvim-fim`, `fimloom.nvim`, `vimsurf.nvim`. All either target local models (Ollama/llama.cpp), use chat-format payloads (not FIM `prompt`/`suffix`), or are single-author experiments. **Decision:** ship a small, self-contained `nvim-config/lua/omni_fim.lua` module (no new plugin dependency) that calls the verified DeepSeek FIM endpoint with `curl`, renders ghost text via an extmark, and no-ops when `DEEPSEEK_API_KEY` is unset. Model/endpoint are configurable via `setup()`.

## 7.5 tmux pane titles

`select-pane -T <title>` (pane title) was added in tmux 3.2 (CHANGES line 888) — matches the repo's existing `tmux >= 3.2` minimum. `pane-border-status top` displays titles in the borders.
