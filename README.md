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
