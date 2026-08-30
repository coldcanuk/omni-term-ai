# Omni Term AI Workspace

A tmux-based terminal workspace with Neovim and pluggable shell AI assistants
("harnesses"). The Command Center window shows two AI assistants side by side
(top-left and top-right panes) plus a plain terminal pane below; an Editor
window runs a packaged Neovim with DeepSeek Fill-In-The-Middle (FIM) code
completion.

## Requirements

These are the runtime requirements **you** provide; the package installs only
configuration and helper scripts:

| Requirement | Minimum | Notes |
| --- | --- | --- |
| tmux | 3.2+ | dedicated socket `omni-term-ai`; pane titles need 3.2+ |
| Neovim | 0.9.5+ | `NVIM_APPNAME=omni-term-ai`; does not touch `~/.config/nvim` |
| git / ripgrep / unzip | — | Neovim plugins (lazy.nvim, Telescope) |
| curl | — | DeepSeek FIM completion in the Editor |
| An AI assistant CLI | — | at least one of: `grok`, `agy`, `copilot`, `claude`, `codex`, `dsh` |
| An API key | — | stored in the OS keychain via `omni-secret` (see below) |

## Supported AI assistants (harnesses)

Configure which assistants fill the top-left and top-right Command Center
panes with `omni-config` — any combination, including the same assistant on
both sides.

| Harness | Binary | Install | Launch | Auth |
| --- | --- | --- | --- | --- |
| grok (xAI Grok Build) | `grok` | `curl -fsSL https://x.ai/cli/install.sh \| bash` | `grok` | browser sign-in, or `XAI_API_KEY` |
| agy (Google Antigravity) | `agy` | `curl -fsSL https://antigravity.google/cli/install.sh \| bash` | `agy` | Google sign-in; optional `GEMINI_API_KEY` |
| copilot (GitHub Copilot CLI) | `copilot` | `brew install copilot-cli` (or `curl -fsSL https://gh.io/copilot-install \| bash`) | `copilot` | `/login`; or `GH_TOKEN` / `GITHUB_TOKEN` |
| claude (Claude Code) | `claude` | `npm install -g @anthropic-ai/claude-code` | `claude` | `claude /login`; or `ANTHROPIC_API_KEY` |
| codex (OpenAI Codex) | `codex` | `npm install -g @openai/codex` | `codex` | `codex login`; or `OPENAI_API_KEY` |
| deepseek (DeepSeek Harness) | `dsh` | `npm install -g @deepseek-ai/dsh` | `dsh web --no-open` | `DEEPSEEK_API_KEY` |

The DeepSeek API key is special: beyond powering the `deepseek` harness, it
drives **FIM (Fill-In-The-Middle) code completion** in the Neovim Editor —
DeepSeek's specialty — with no extra subscription.

`launch-ai-workspace` validates your two chosen harnesses before starting:
if a binary is missing it prints the exact install command for that harness
and exits, so you never get an empty pane by accident.

## Security First: No Clear-Text API Keys

This project does not write API keys in `~/.bashrc` or `.env` files. `omni-secret` stores and fetches keys from the native OS secret store:

| Platform | Backend |
| --- | --- |
| Ubuntu / Debian / Fedora | `secret-tool` (libsecret / GNOME Keyring) |
| macOS | `security` (Keychain) |
| OpenBSD | `pass` if installed, otherwise `~/.config/omni-term-ai/secrets/` (mode 0600) |

Store the keys for whichever harnesses you use:

```bash
omni-secret store xai        # grok            -> XAI_API_KEY
omni-secret store deepseek   # deepseek + FIM  -> DEEPSEEK_API_KEY
omni-secret store anthropic  # claude          -> ANTHROPIC_API_KEY
omni-secret store openai     # codex           -> OPENAI_API_KEY
omni-secret store github     # copilot         -> GH_TOKEN / GITHUB_TOKEN
omni-secret store gemini     # agy (optional)  -> GEMINI_API_KEY
```

Linux equivalent without the helper:

```bash
secret-tool store --label="xAI API Key" api xai
secret-tool store --label="Deepseek API Key" api deepseek
```

`omni-exec` injects every harness key (`XAI_API_KEY`, `DEEPSEEK_API_KEY`,
`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GH_TOKEN`, `GEMINI_API_KEY`) into a
single command's environment; `launch-ai-workspace` does the same for the
whole tmux session. Keys you never stored are exported empty, so interactive
logins (browser sign-in, `/login`) still work.

## Choose your assistants: omni-config

```bash
omni-config          # interactive wizard: pick left and right harnesses
omni-config list     # supported harnesses + installed status + install hints
omni-config get      # show current left/right selection
omni-config set left codex
omni-config set right claude
omni-config path     # where the config lives
```

Examples:

```bash
omni-config set left copilot && omni-config set right copilot   # copilot on both
omni-config set left agy    && omni-config set right grok       # agy left, grok right
omni-config set left codex  && omni-config set right claude     # codex left, claude right
```

The config file is plain POSIX shell at
`~/.config/omni-term-ai/config` (`$XDG_CONFIG_HOME` honored):

```sh
OMNI_LEFT_HARNESS=agy
OMNI_RIGHT_HARNESS=grok
```

Defaults are `agy` (left) and `grok` (right).

## DeepSeek FIM completion in the Editor

With `DEEPSEEK_API_KEY` stored, the Editor window shows ghost-text
completions as you type (insert mode, ~120 ms debounce). Completions call
DeepSeek's FIM endpoint:

```
POST https://api.deepseek.com/beta/completions
{ "model": "deepseek-v4-pro", "prompt": <text before cursor>,
  "suffix": <text after cursor>, "max_tokens": 128, "temperature": 0 }
```

- **`<Tab>`** accepts the ghost completion (falls through to a real Tab when
  none is shown)
- **`<C-e>`** dismisses it
- Without a stored DeepSeek key the plugin quietly does nothing; the Editor
  works normally.

Options live at the bottom of `nvim-config/init.lua`
(`require("omni_fim").setup({ ... })`): model, endpoint, debounce, context
window, keymaps, highlight group. FIM output is capped at 4K tokens by the
API.

## DeepSeek AI Bash Tab Completion

You can integrate DeepSeek directly into your actual terminal's bash shell. When enabled, hitting `<Tab>` will predict and complete text using DeepSeek FIM, presenting choices above your cursor. This also seamlessly enables Neovim's inline AI completions when run outside of the tmux workspace.

Add the following to your `~/.bashrc`:
```bash
# Omni Term AI integration
. $HOME/.local/share/omni-term-ai/lib/omni-bash.sh
```
*(Adjust the path if you installed to a different prefix.)*

Make sure you have stored your DeepSeek key using `omni-secret store deepseek`.

## License

GPLv3

## Install

Pick the path for your OS. All of them install the same files via `make install`.

### Ubuntu / Debian / Pop!_OS

```bash
sudo apt update
sudo apt install tmux neovim git build-essential ripgrep unzip libsecret-tools
git clone https://github.com/coldcanuk/omni-term-ai.git
cd omni-term-ai
sudo make install PREFIX=/usr
```

Or install a `.deb` built from this tree:

```bash
make deb
sudo apt install ./dist/omni-term-ai_*_all.deb
```

### Fedora / RHEL / Rocky / AlmaLinux

```bash
sudo dnf install tmux neovim git gcc make ripgrep unzip libsecret
git clone https://github.com/coldcanuk/omni-term-ai.git
cd omni-term-ai
sudo make install PREFIX=/usr
```

With `rpm-build` installed, `make rpm` writes RPMs under `dist/`.

### macOS (Homebrew)

Homebrew 6.0+ **requires tapping repos to be trusted** before their formulae
may be evaluated (`brew trust`). Until a `homebrew-omni-term-ai` tap repo
exists, tap this project by URL and trust it (head-only until a tagged
release):

```bash
brew tap coldcanuk/omni-term-ai https://github.com/coldcanuk/omni-term-ai
brew trust coldcanuk/omni-term-ai
brew install --HEAD omni-term-ai
```

Prefer trusting just this formula instead of the whole tap?

```bash
brew tap coldcanuk/omni-term-ai https://github.com/coldcanuk/omni-term-ai
brew trust --formula coldcanuk/omni-term-ai/omni-term-ai
brew install --HEAD coldcanuk/omni-term-ai/omni-term-ai
```

From a checkout (no trust step needed for the in-tree formula):

```bash
brew install --HEAD --formula ./Formula/omni-term-ai.rb
```

Manage trust with `brew untrust coldcanuk/omni-term-ai` or list trusted
entries with `brew trust --json=v1`.

### OpenBSD

tmux is in the base system.

```sh
doas pkg_add neovim git ripgrep
git clone https://github.com/coldcanuk/omni-term-ai.git
cd omni-term-ai
doas make install PREFIX=/usr/local
```

A ports skeleton lives in `packaging/openbsd/sysutils/omni-term-ai/` for `/usr/ports/mystuff`. Official `pkg_add omni-term-ai` requires the port to be imported upstream.

### Any Unix (user prefix)

```bash
git clone https://github.com/coldcanuk/omni-term-ai.git
cd omni-term-ai
./install.sh --deps --prefix "$HOME/.local"
```

Put `$HOME/.local/bin` on `PATH`.

## Usage

```bash
omni-secret store xai
omni-secret store deepseek
omni-config                     # optional: pick your panes' assistants
launch-ai-workspace
```

The launcher uses a dedicated tmux socket (`omni-term-ai`) and `NVIM_APPNAME=omni-term-ai`, so it does not replace `~/.config/nvim` or your default tmux server. Harness names appear in each pane's top border.

Packaging internals are documented in `packaging/PACKAGING.md`.
