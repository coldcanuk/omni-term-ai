# Omni Term AI Workspace

A fully integrated tmux-based terminal workspace with Neovim, xAI (Grok), and DeepSeek AI tab-completion. 

## Security First: No Clear-Text API Keys
This project completely avoids writing API keys in clear text in your `~/.bashrc` or `.env` files. Instead, it dynamically queries your OS keychain (GNOME Keyring / Secret Service API) on the fly using `secret-tool`.

**Setup your keys:**
```bash
secret-tool store --label="xAI API Key" api xai
secret-tool store --label="Deepseek API Key" api deepseek
```
The wrapper scripts in this repository will dynamically fetch these keys only when making API calls, ensuring your keys are never stored on disk in plaintext or left hanging in your global bash environment.

## License
GPLv3

## Dependencies

To run the Omni Term AI workspace seamlessly, ensure the following dependencies are installed on your system:

- **tmux** (3.2 or newer) - For the dual-tab architecture and window management.
- **Neovim** (0.9.5 or newer) - For the embedded, full-screen editor environment.
- **git** - Required for Neovim's `lazy.nvim` package manager.
- **gcc** or **make** - Required to compile Treesitter parsers and Telescope's C-port.
- **ripgrep** (`rg`) - Required for Telescope's blazing-fast fuzzy finding and grep search.
- **unzip** - Required for various Neovim plugin installations.
- **libsecret-tools** - Provides `secret-tool` for the dynamic, secure credential fetching.

### Installation on Ubuntu / Pop!_OS:
```bash
sudo apt update
sudo apt install tmux neovim git build-essential ripgrep unzip libsecret-tools
```
