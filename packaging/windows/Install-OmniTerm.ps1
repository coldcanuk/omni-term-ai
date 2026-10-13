# Install Omni Term AI into Ubuntu on WSL.
# Run from Windows PowerShell. Administrator is required only when Ubuntu is missing.
$ErrorActionPreference = "Stop"

function Get-WslNames {
    $raw = & wsl.exe -l -q 2>$null
    if (-not $raw) { return @() }
    $names = @()
    foreach ($line in $raw) {
        $name = (($line -replace "`0", "")).Trim()
        if ($name) { $names += $name }
    }
    return $names
}

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    Write-Error "WSL is not installed. From an Administrator PowerShell run: wsl --install -d Ubuntu"
}

$names = Get-WslNames
$distro = $null
foreach ($name in $names) {
    if ($name -eq "Ubuntu") { $distro = "Ubuntu"; break }
}
if (-not $distro) {
    foreach ($name in $names) {
        if ($name -like "Ubuntu*") { $distro = $name; break }
    }
}
if (-not $distro) {
    Write-Error "Ubuntu is not installed. From an Administrator PowerShell run: wsl --install -d Ubuntu"
}

# bash -s reads this script from stdin. setup-apt.sh then uses the network itself.
$script = @'
set -eu
if ! command -v curl >/dev/null 2>&1 || ! command -v gpg >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y curl gnupg ca-certificates
fi
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
curl -fsSL https://raw.githubusercontent.com/coldcanuk/omni-term-ai/main/packaging/setup-apt.sh -o "$tmp"
sh "$tmp"
'@

$script | & wsl.exe -d $distro -- bash -s
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Installed into $distro. Open that distro and run: launch-ai-workspace"
