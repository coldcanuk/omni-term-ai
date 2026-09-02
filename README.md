# Omni Term AI Workspace

A tmux-based terminal workspace with Neovim and pluggable shell AI assistants ("harnesses"). The Command Center window shows two AI assistants side by side (top-left and top-right panes) plus a plain terminal pane below; an Editor window runs a packaged Neovim with DeepSeek Fill-In-The-Middle (FIM) code completion.

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Shortcut Keys](#shortcut-keys)
- [Features](#features)
  - [Command Center Configuration](#command-center-configuration)
  - [Remote Workspaces (Jumpbox)](#remote-workspaces-jumpbox)
  - [DeepSeek FIM Editor Completion](#deepseek-fim-editor-completion)
  - [DeepSeek AI Bash Completion](#deepseek-ai-bash-completion)
- [Supported AI Assistants](#supported-ai-assistants)
- [Security: API Keys](#security-api-keys)
- [License](#license)

## Requirements

These are the runtime requirements **you** provide; the package installs only configuration and helper scripts:

| Requirement | Minimum | Notes |
| --- | --- | --- |
| tmux | 3.2+ | dedicated socket `omni-term-ai`; pane titles need 3.2+ |
| Neovim | 0.9.5+ | `NVIM_APPNAME=omni-term-ai`; does not touch `~/.config/nvim` |
| git / ripgrep / unzip | — | Neovim plugins (lazy.nvim, Telescope) |
| curl | — | DeepSeek FIM completion in the Editor |
| An AI assistant CLI | — | at least one of: `grok`, `agy`, `copilot`, `claude`, `codex`, `dsh` |
| An API key | — | stored in the OS keychain via `omni-secret` (see below) |

## Installation

Pick the path for your OS. All of them install the same files via `make install`.

### Windows 11 (WSL)
Are you on Windows? See our [Step-by-Step Windows 11 WSL Guide](WINDOWS_WSL.md) for full setup instructions!

### Debian / Pop!OS / Ubuntu
Supported Package: **`.deb`**

Download and install the latest `.deb` package from our [Releases page](https://github.com/coldcanuk/omni-term-ai/releases):
```bash
wget $(curl -s https://api.github.com/repos/coldcanuk/omni-term-ai/releases/latest | grep "browser_download_url.*\.deb" | cut -d '"' -f 4) -O omni-term-ai.deb
sudo apt update
sudo apt install ./omni-term-ai.deb
```

### Fedora / RedHat (RHEL) / AlmaLinux
Supported Package: **`.rpm`**

Download and install the latest `.rpm` package from our [Releases page](https://github.com/coldcanuk/omni-term-ai/releases):
```bash
wget $(curl -s https://api.github.com/repos/coldcanuk/omni-term-ai/releases/latest | grep "browser_download_url.*\.noarch\.rpm" | cut -d '"' -f 4) -O omni-term-ai.rpm
sudo dnf install ./omni-term-ai.rpm
```

### Omarchy / Arch Linux / Manjaro
Supported Package: **`PKGBUILD`**

Download the `PKGBUILD` from our [Releases page](https://github.com/coldcanuk/omni-term-ai/releases) and use `makepkg` to build and install it, or use your favorite AUR helper:
```bash
yay -S omni-term-ai
```

### MacOSX
Supported Package: **`.pkg`** (and Homebrew Formula)

Run `make macosx` or `make macos` to build a native macOS installer `.pkg` in `dist/`, or install directly via Homebrew:
```bash
brew tap coldcanuk/omni-term-ai https://github.com/coldcanuk/omni-term-ai
brew trust coldcanuk/omni-term-ai
brew install --HEAD omni-term-ai
```

### OpenBSD & FreeBSD
Supported Packages: **Ports Skeleton**

- **OpenBSD**: Run `make openbsd` to prepare the ports skeleton (`/usr/ports/mystuff/sysutils/omni-term-ai`).
- **FreeBSD**: Run `make freebsd` to prepare the FreeBSD ports directory.

### Developer Instructions / Building from source
If you are a developer or want to install from source, these are the correct instructions for compiling:
```bash
git clone https://github.com/coldcanuk/omni-term-ai.git
cd omni-term-ai
./configure
make clean
make
sudo make install
```
*Note: Depending on your OS, you will need to install the dependencies (e.g. `tmux`, `neovim`, `git`, `ripgrep`, `unzip`, `libsecret`). You can also use `./install.sh --deps --prefix "$HOME/.local"` for a local user install.*


## Usage

```bash
# Store your API keys in the native OS keychain
omni-secret store xai
omni-secret store deepseek

# Launch the workspace! (Will run first-time setup if unconfigured)
launch-ai-workspace
```

The launcher uses a dedicated tmux socket (`omni-term-ai`) and `NVIM_APPNAME=omni-term-ai`, so it does not replace `~/.config/nvim` or your default tmux server.

## Shortcut Keys

The workspace is powered by tmux. By default, the tmux prefix is `Ctrl+b`. Here are the custom workspace shortcuts:

- **`Prefix + ?`**: **Show Help Window** (list of all bound shortcut keys)
- **`Prefix + h/j/k/l`**: Navigate panes (left/down/up/right)
- **`Prefix + Shift + H/J/K/L`**: Resize current pane
- **`Prefix + e`**: Dual-Tab Toggle (instantly switch between Command Center and Editor tabs)
- **`Prefix + E`**: Panic Button (kills the Editor tab and spawns a fresh Neovim instance)
- **`Prefix + Space`**: Toggle the floating scratchpad terminal
- **`Prefix + n`**: Open Neovim with Neotree in the current focused pane

## Features

### Command Center Configuration

Configure which assistants fill the top-left and top-right Command Center panes. You will be prompted automatically on your first run, but you can change it anytime with `omni-config`:

```bash
omni-config          # interactive wizard: pick left, right harnesses and jumpbox
omni-config list     # supported harnesses + installed status + install hints
omni-config get      # show current selection
omni-config path     # where the config lives
```

Manual overrides:
```bash
omni-config set left copilot && omni-config set right copilot   # copilot on both
omni-config set left agy    && omni-config set right grok       # agy left, grok right
```

### Remote Workspaces (Jumpbox)

Omni Term AI supports seamlessly developing on remote targets via an optional Jumpbox architecture. 

1. **Setup**: Run `omni-config` and enter your jumpbox address when prompted, or manually set it: 
   `omni-config set jumpbox user@jumpbox.example.com`
2. **Launch**: Start a session with the `@` prefix for your remote target:
   `launch-ai-workspace @production-server`

The workspace will SSH to your jumpbox, mount `production-server:/` locally onto the jumpbox using `sshfs`, and seamlessly run the AI workspace on the remote code!

### FIM Editor Completion (DeepSeek, OpenAI, Azure)

With an API key stored via `omni-secret`, the Editor window shows ghost-text completions as you type (insert mode, ~120 ms debounce). Completions call Fill-In-The-Middle (FIM) endpoints.

**DeepSeek FIM**: Uses `DEEPSEEK_API_KEY`.
**OpenAI FIM**: Uses `OPENAI_API_KEY` (uses the `gpt-3.5-turbo-instruct` model).
**Azure OpenAI FIM**: Uses `AZURE_OPENAI_API_KEY` (requires `AZURE_OPENAI_ENDPOINT` and `AZURE_OPENAI_DEPLOYMENT` exported in your bashrc).

- **`<Tab>`** accepts the ghost completion
- **`<C-e>`** dismisses it
- Without a stored key, the plugin quietly does nothing.

*(Note for corporate environments: You can also use GitHub Copilot instead by installing the official `copilot.vim` plugin in your `~/.config/nvim` directory!)*

Options live at the bottom of `nvim-config/init.lua` (`require("omni_fim").setup({ ... })`).

### FIM Bash Completion

You can integrate FIM directly into your actual terminal's bash shell. When enabled, hitting `<Ctrl-F>` will predict and complete text using FIM (DeepSeek, OpenAI, or Azure), presenting choices above your cursor.

Add the following to your `~/.bashrc`:
```bash
# Omni Term AI integration
. $HOME/.local/share/omni-term-ai/lib/omni-bash.sh
```

## Supported AI Assistants

| Harness | Binary | Install | Launch | Auth |
| --- | --- | --- | --- | --- |
| grok (xAI Grok Build) | `grok` | `curl -fsSL https://x.ai/cli/install.sh \| bash` | `grok` | browser sign-in, or `XAI_API_KEY` |
| agy (Google Antigravity) | `agy` | `curl -fsSL https://antigravity.google/cli/install.sh \| bash` | `agy` | Google sign-in; optional `GEMINI_API_KEY` |
| copilot (GitHub Copilot CLI) | `copilot` | `brew install copilot-cli` | `copilot` | `/login`; or `GH_TOKEN` |
| claude (Claude Code) | `claude` | `npm install -g @anthropic-ai/claude-code` | `claude` | `claude /login`; or `ANTHROPIC_API_KEY` |
| codex (OpenAI Codex) | `codex` | `npm install -g @openai/codex` | `codex` | `codex login`; or `OPENAI_API_KEY` |
| deepseek (DeepSeek Harness) | `dsh` | `npm install -g @deepseek-ai/dsh` | `dsh web --no-open` | `DEEPSEEK_API_KEY` |

`launch-ai-workspace` validates your two chosen harnesses before starting. If missing, it prints the install command.

## Security: API Keys

This project does not write API keys in plain text. `omni-secret` stores and fetches keys from the native OS secret store (libsecret on Linux, Keychain on macOS).

```bash
omni-secret store xai        # grok            -> XAI_API_KEY
omni-secret store deepseek   # deepseek + FIM  -> DEEPSEEK_API_KEY
omni-secret store anthropic  # claude          -> ANTHROPIC_API_KEY
omni-secret store openai     # codex           -> OPENAI_API_KEY
omni-secret store github     # copilot         -> GH_TOKEN / GITHUB_TOKEN
omni-secret store gemini     # agy (optional)  -> GEMINI_API_KEY
omni-secret store azure      # azure fim       -> AZURE_OPENAI_API_KEY
```

`omni-exec` securely injects the keys into the harnesses at runtime. Keys you never stored are exported empty, so interactive browser logins still work perfectly.

## License

GPLv3
