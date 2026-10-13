# Installing Omni Term AI on Windows 11 via WSL

Windows Subsystem for Linux is the supported way to run Omni Term AI on Windows. Use Ubuntu. The package is the same signed `.deb` a native Ubuntu machine installs. A few Windows details are not plain Ubuntu: the secret store, the clipboard, and where project files should live.

## Step 1: Install WSL (Ubuntu)

1. Open **PowerShell** as Administrator.
2. Run:

   ```powershell
   wsl --install -d Ubuntu
   ```

   That installs WSL 2 and Ubuntu. Restart if Windows asks.
3. The first Ubuntu window asks for a UNIX username and password. That password is for `sudo` inside Linux. It does not have to match your Windows password.

If Ubuntu is already installed, skip this step.

## Step 2: Install Omni Term AI

From PowerShell (Administrator is not required once Ubuntu exists):

```powershell
wsl -d Ubuntu -- bash -lc "curl -fsSL https://raw.githubusercontent.com/coldcanuk/omni-term-ai/main/packaging/setup-apt.sh | sh"
```

The script in this repository, [`packaging/windows/Install-OmniTerm.ps1`](packaging/windows/Install-OmniTerm.ps1), does the same thing and picks `Ubuntu` if several distros are installed.

Or, inside the Ubuntu terminal, use the signed repository directly:

```bash
curl -fsSL https://coldcanuk.github.io/omni-term-ai/omni-term-ai.gpg \
  | sudo tee /usr/share/keyrings/omni-term-ai.gpg >/dev/null
gpg --show-keys /usr/share/keyrings/omni-term-ai.gpg
# expect B395 A979 72B3 09A3 E4CE  D62A B1C4 CFC6 85A8 F91B
echo "deb [signed-by=/usr/share/keyrings/omni-term-ai.gpg] https://coldcanuk.github.io/omni-term-ai/apt /" \
  | sudo tee /etc/apt/sources.list.d/omni-term-ai.list
sudo apt update
sudo apt install omni-term-ai
```

Do not download a versioned `.deb` by guessing the filename. Release asset names include the version (`omni-term-ai_<version>_all.deb`). The apt repository tracks the tagged release.

npm works inside WSL, not from `cmd.exe`:

```bash
npm install -g github:coldcanuk/omni-term-ai
```

## Step 3: Store API keys

`omni-secret` prefers libsecret. On WSL the `secret-tool` binary is often installed while the session bus is not running. Calling it then hangs. Omni Term AI will not select `secret-tool` unless `DBUS_SESSION_BUS_ADDRESS` is set or `/run/user/<uid>/bus` exists. It falls back to `pass`, then to a mode-0600 file under `~/.config/omni-term-ai/secrets/`.

To use the keyring:

```bash
sudo apt install -y dbus gnome-keyring
sudo service dbus start
eval "$(gnome-keyring-daemon --start)"
export DBUS_SESSION_BUS_ADDRESS
omni-secret store xai
omni-secret store deepseek
```

`agy` is not a secret name. The optional Antigravity key is `omni-secret store gemini`. Names are `xai`, `deepseek`, `anthropic`, `openai`, `github`, `gemini`, and `azure`.

If the keyring will not start (common when systemd is off), store the key in the file backend instead:

```bash
OMNI_SECRET_BACKEND=file omni-secret store xai
```

WSL can enable systemd in `/etc/wsl.conf`, then `wsl --shutdown` from PowerShell:

```ini
[boot]
systemd=true
```

With systemd, `systemctl --user enable --now gnome-keyring-daemon.service` replaces `sudo service dbus start`.

## Step 4: Launch

```bash
launch-ai-workspace
```

From PowerShell, without opening Ubuntu first:

```powershell
wsl -d Ubuntu -- launch-ai-workspace
```

## Windows details

1. **Windows Terminal.** Use it for the Ubuntu profile. A Nerd Font (FiraCode Nerd Font is fine) belongs on the Windows side, as the terminal font, not inside the `.deb`.
2. **Clipboard.** The Editor sets `clipboard=unnamedplus` and, under WSL, copies with `clip.exe` and pastes with `powershell.exe`. That needs Windows interop. In `/etc/wsl.conf`:

   ```ini
   [interop]
   enabled=true
   appendWindowsPath=true
   ```

   Then `wsl --shutdown` and open Ubuntu again. `clip.exe` must be on `PATH`.
3. **Where to keep projects.** `/mnt/c` is the Windows `C:\` drive. It works, and it is slow for Neovim and git. Keep repositories in the Linux filesystem (`~/src`) unless a Windows tool has to see the files.
4. **Line endings.** Shell scripts in this repository are LF. If you clone on the Windows filesystem, set `git config core.autocrlf false` before copying the tree into WSL. A CRLF shebang will not run.
5. **Other distros.** Debian and Ubuntu derivatives inside WSL can use `./install.sh --package`. Arch on WSL can use `./install.sh --package` once a release has an Arch asset, or `make arch`.
