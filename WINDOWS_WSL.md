# Installing Omni Term AI on Windows 11 via WSL

Windows Subsystem for Linux (WSL) allows you to run a full Linux environment directly on Windows. This is the recommended way to use Omni Term AI on Windows 11.

## Step 1: Install WSL (Ubuntu)

1. Open **PowerShell** or **Command Prompt** as **Administrator**. (Right-click the Start button and select "Windows Terminal (Admin)" or "Windows PowerShell (Admin)").
2. Run the following command:
   ```powershell
   wsl --install
   ```
   *Note: This installs WSL 2 and the default Ubuntu Linux distribution.*
3. Restart your computer if prompted.
4. After restarting, a terminal window will appear to complete the Ubuntu installation. You will be prompted to create a **UNIX username** and **password**. (This password is used for `sudo` commands inside Linux, and does not need to match your Windows password).

## Step 2: Keep WSL Updated

Inside your new Ubuntu terminal, make sure the base system is up to date:
```bash
sudo apt update && sudo apt upgrade -y
```

## Step 3: Install Omni Term AI

Since WSL runs a standard Ubuntu Linux environment, you can follow the exact same instructions as a native Ubuntu system!

### Option A: Install from GitHub Releases (Recommended)
1. Download the latest `.deb` package directly inside WSL using `wget` (replace the version number with the latest from the [GitHub Releases](https://github.com/coldcanuk/omni-term-ai/releases) page):
   ```bash
   wget https://github.com/coldcanuk/omni-term-ai/releases/latest/download/omni-term-ai_0.2.1_all.deb
   ```
2. Install the package:
   ```bash
   sudo apt install ./omni-term-ai_*_all.deb
   ```

### Option B: Install from Source
If you prefer to build the package yourself:
```bash
sudo apt install tmux neovim git build-essential ripgrep unzip libsecret-tools
git clone https://github.com/coldcanuk/omni-term-ai.git
cd omni-term-ai
sudo make install PREFIX=/usr
```

## Step 4: Configure the API Keys

Omni Term AI requires API keys for your preferred AI assistants. Ubuntu on WSL uses `libsecret` to safely store these keys.

1. Ensure the secret tool is running (WSL sometimes requires `dbus` to be started manually):
   ```bash
   sudo service dbus start
   ```
2. Store your keys using the `omni-secret` helper. For example:
   ```bash
   omni-secret store deepseek
   omni-secret store agy
   ```
   *Paste your API key when prompted.*

## Step 5: Launch Omni Term AI

You are all set! Launch the workspace by running:
```bash
launch-ai-workspace
```

Your Neovim editor and AI panes will appear directly within your WSL terminal.

---

### Pro-Tips for Windows Users

1. **Use Windows Terminal**: For the best visual experience, use the official **Windows Terminal** (available in the Microsoft Store or pre-installed on Windows 11). It offers excellent color rendering and tab support for WSL.
2. **Install a Nerd Font**: Neovim plugins often use icons that require a Nerd Font. Download a font like [FiraCode Nerd Font](https://www.nerdfonts.com/), install it in Windows, and set it as the default font for your Ubuntu profile in Windows Terminal settings.
3. **Accessing Windows Files**: Your Windows `C:\` drive is mounted inside WSL at `/mnt/c/`. You can easily edit your Windows project files from inside the Omni Term AI workspace by navigating there!
