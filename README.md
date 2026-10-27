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
| python3 | — | optional; bash FIM completion only |
| sshfs | — | optional; on the jumpbox, for a remote target |
| An AI assistant CLI | — | at least one of: `grok`, `agy`, `copilot`, `claude`, `codex`, `dsh` |
| An API key | — | stored in the OS keychain via `omni-secret` (see below) |

## Installation

Pick the path for your OS. Package installs use `PREFIX=/usr`. A source install defaults to `~/.local`. Tagged releases publish the `.deb`, `.rpm`, and macOS `.pkg` and update the signed apt and rpm repositories. `packaging/attach-release-extras.sh` uploads the Arch package and npm tarball to that same [GitHub release](https://github.com/coldcanuk/omni-term-ai/releases).

### Windows 11 (WSL)

Windows is supported through WSL, usually Ubuntu. See the [Windows 11 WSL guide](WINDOWS_WSL.md). From PowerShell, [`packaging/windows/Install-OmniTerm.ps1`](packaging/windows/Install-OmniTerm.ps1) installs into Ubuntu with the signed apt repository. Inside WSL, use the Debian instructions below.

Two things are not plain Ubuntu. If the session bus is down, `omni-secret` does not call `secret-tool` (that call hangs) and uses `pass` or a mode-0600 file instead. The Editor clipboard uses `clip.exe`, so Windows interop must stay on (`appendWindowsPath=true` in `/etc/wsl.conf`).

### Debian / Pop!_OS / Ubuntu

Supported package: **`.deb`**, from the signed apt repository. Ubuntu on WSL uses this path.

```bash
curl -fsSL https://raw.githubusercontent.com/coldcanuk/omni-term-ai/main/packaging/setup-apt.sh | sh
```

Or the same steps by hand:

```bash
curl -fsSL https://coldcanuk.github.io/omni-term-ai/omni-term-ai.gpg \
  | sudo tee /usr/share/keyrings/omni-term-ai.gpg >/dev/null
gpg --show-keys /usr/share/keyrings/omni-term-ai.gpg   # expect B395 A979 72B3 09A3 E4CE  D62A B1C4 CFC6 85A8 F91B
echo "deb [signed-by=/usr/share/keyrings/omni-term-ai.gpg] https://coldcanuk.github.io/omni-term-ai/apt /" \
  | sudo tee /etc/apt/sources.list.d/omni-term-ai.list
sudo apt update
sudo apt install omni-term-ai
```

`./install.sh --package` runs that signed setup. The repository updates when a version is tagged. Added it before 0.3.0 with `trusted=yes`? Run the commands above. The second `tee` replaces that line.

### Fedora / RedHat (RHEL) / AlmaLinux
Supported Package: **`.rpm`**

Add our signed repository to receive future updates:
```bash
cat <<REPO | sudo tee /etc/yum.repos.d/omni-term-ai.repo
[omni-term-ai]
name=Omni Term AI Repository
baseurl=https://coldcanuk.github.io/omni-term-ai/rpm
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://coldcanuk.github.io/omni-term-ai/omni-term-ai.asc
REPO

sudo dnf install omni-term-ai
```

dnf asks you to confirm the key on first use. Its fingerprint must be `B395 A979 72B3 09A3 E4CE  D62A B1C4 CFC6 85A8 F91B`.

#### Repository signing key
Packages and repository metadata are signed with **Omni Term AI Repository Signing** (RSA 4096, expires 2029-10-12):

```
B395 A979 72B3 09A3 E4CE  D62A B1C4 CFC6 85A8 F91B
```

The same public key is in this repository at [`packaging/repo-signing-key.asc`](packaging/repo-signing-key.asc). Check that it matches the key served by the package site.

### Omarchy / Arch Linux / Manjaro

Supported package: **pacman**. Omarchy is Arch (`ID=omarchy`), so it uses this package. There is no AUR package.

Build it on the machine (`makepkg` and `base-devel`):

```bash
git clone https://github.com/coldcanuk/omni-term-ai.git
cd omni-term-ai
make arch
sudo pacman -U dist/omni-term-ai-*-any.pkg.tar.zst
```

After a release has an Arch asset, this downloads it and installs it:

```bash
./install.sh --package
```

`./install.sh --deps` installs runtime packages with `pacman` on Arch, Omarchy, Manjaro, and EndeavourOS, then installs this tree under `~/.local`.

### npm

Install the launchers with npm from this repository. The name is not published on the npm registry.

```bash
npm install -g github:coldcanuk/omni-term-ai
```

A release also carries `omni-term-ai-<version>.tgz` for `npm install -g <tarball>`. On Windows, run that inside WSL, not in `cmd.exe`.

### macOS

Supported package: **`.pkg`** (and a Homebrew formula). The formula is head-only.

Run `make macos` (alias `make macosx`) to build a native macOS installer `.pkg` in `dist/`, or install from the tap:

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
*Note: Depending on your OS, you will need to install the dependencies (e.g. `tmux`, `neovim`, `git`, `ripgrep`, `unzip`, `curl`, `libsecret`). `python3` and `sshfs` are optional. You can also use `./install.sh --deps --prefix "$HOME/.local"` for a local user install. On Debian, Ubuntu, Arch, and Omarchy, `./install.sh --package` installs the distro package instead.*





## Uninstallation

If you installed via a package manager (`apt`, `dnf`, `pacman`, `brew`, `npm`), use that package manager to remove `omni-term-ai` (`npm uninstall -g omni-term-ai`).

If you installed from source or using the local installation scripts, you can uninstall by running:
```bash
./uninstall.sh
# or if you used a custom prefix:
./uninstall.sh --prefix /usr
```

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
- **`Prefix + Shift + W`**: Open a watch row. The current pane becomes a 24-row assistant rectangle with an 80-column pane beside it. That pane runs `ceci status --watch` when `ceci` is on `PATH` and `OMNI_CECI_WORK_DIR` is set. The launcher also opens this row when a pane shows `/cecicela` and `--watch` on the same line. A `--work-dir` on that line is the work directory.
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

Omni Term AI supports an optional jumpbox. Set it with `omni-config set jumpbox user@jumpbox.example.com`.

If a jumpbox is configured, `launch-ai-workspace` with no arguments SSHes to that host and starts the workspace there. It does not sshfs-mount the jumpbox itself. Set `OMNI_SKIP_JUMPBOX=1` to stay local anyway.

To work on a machine reached through the jumpbox:

```bash
launch-ai-workspace @production-server
```

That SSHes to the jumpbox, mounts `production-server:/` there with `sshfs`, and starts the workspace in that mount. `sshfs` must be installed on the jumpbox. A failed mount aborts. The target is passed as one quoted argument.

### FIM Editor Completion (DeepSeek, OpenAI, Azure)

With an API key stored via `omni-secret`, the Editor window shows ghost-text completions as you type (insert mode, ~120 ms debounce). Completions call Fill-In-The-Middle (FIM) endpoints.

**DeepSeek FIM**: Uses `DEEPSEEK_API_KEY`.
**OpenAI FIM**: Uses `OPENAI_API_KEY` (uses the `gpt-3.5-turbo-instruct` model).
**Azure OpenAI FIM**: Uses `AZURE_OPENAI_API_KEY` from `omni-secret store azure`. Set the endpoint and deployment in config (they are not secrets), and the launcher injects all three into the tmux session:

```bash
omni-config set azure-endpoint https://example.openai.azure.com
omni-config set azure-deployment my-deployment
```

- **`<Tab>`** accepts the ghost completion
- **`<C-e>`** dismisses it
- Without a stored key, the plugin quietly does nothing.

*(Note for corporate environments: You can also use GitHub Copilot instead by installing the official `copilot.vim` plugin in your `~/.config/nvim` directory!)*

Options live at the bottom of `nvim-config/init.lua` (`require("omni_fim").setup({ ... })`).

### FIM Bash Completion

You can integrate FIM directly into your actual terminal's bash shell. When enabled, hitting `<Ctrl-F>` asks the configured provider (`OMNI_FIM_PROVIDER`, default `deepseek`) for a completion. One choice is inserted. Several choices are a numbered pick; the one you choose is inserted. This needs `python3`. It does not run the model's text as shell.

Add the following to your `~/.bashrc`. `omni-config` must be on `PATH`. This works for a `/usr/local` install and for a `~/.local` install:
```bash
# Omni Term AI integration
. "$(omni-config home)/lib/omni-bash.sh"
```

Sourcing that file does not change `NVIM_APPNAME`. The launcher still sets it for the workspace. Set `OMNI_USE_NVIM_CONFIG=1` before sourcing if this shell's `nvim` should use the packaged config.

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

`omni-exec` injects stored keys into the harness environment. A key you never stored is not written as an empty value, so an ambient token or a browser login is left alone.

## License

GPLv3
