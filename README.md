# Omni Term AI Workspace

A tmux-based terminal workspace with Neovim, xAI (Grok), and DeepSeek AI tab-completion.

## Security First: No Clear-Text API Keys

This project does not write API keys in `~/.bashrc` or `.env` files. `omni-secret` stores and fetches keys from the native OS secret store:

| Platform | Backend |
| --- | --- |
| Ubuntu / Debian / Fedora | `secret-tool` (libsecret / GNOME Keyring) |
| macOS | `security` (Keychain) |
| OpenBSD | `pass` if installed, otherwise `~/.config/omni-term-ai/secrets/` (mode 0600) |

```bash
omni-secret store xai
omni-secret store deepseek
```

Linux equivalent without the helper:

```bash
secret-tool store --label="xAI API Key" api xai
secret-tool store --label="Deepseek API Key" api deepseek
```

`omni-exec` injects `XAI_API_KEY` and `DEEPSEEK_API_KEY` into a single command's environment.

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

This repository includes `Formula/omni-term-ai.rb`. Until a `homebrew-omni-term-ai` tap repo exists, tap this project by URL (head-only until a tagged release):

```bash
brew tap coldcanuk/omni-term-ai https://github.com/coldcanuk/omni-term-ai
brew install --HEAD omni-term-ai
```

From a checkout:

```bash
brew install --HEAD --formula ./Formula/omni-term-ai.rb
```

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
launch-ai-workspace
```

The launcher uses a dedicated tmux socket (`omni-term-ai`) and `NVIM_APPNAME=omni-term-ai`, so it does not replace `~/.config/nvim` or your default tmux server.

Packaging internals are documented in `packaging/PACKAGING.md`.
