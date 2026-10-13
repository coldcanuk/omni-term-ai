#!/bin/sh
# Install surfaces: signed apt setup, Arch/Omarchy package setup, npm
# package metadata, and WSL secret-store fallback.
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
fail() { echo "FAIL: $*" >&2; exit 1; }

out=$(sh "$ROOT/packaging/setup-apt.sh" --dry-run)
printf '%s\n' "$out" | grep -F 'B395A97972B309A3E4CED62AB1C4CFC685A8F91B' >/dev/null \
    || fail "apt dry-run omitted the signing fingerprint: $out"
printf '%s\n' "$out" | grep -F 'signed-by=/usr/share/keyrings/omni-term-ai.gpg' >/dev/null \
    || fail "apt dry-run omitted signed-by: $out"
printf '%s\n' "$out" | grep -F 'trusted=yes' >/dev/null && fail "apt dry-run uses trusted=yes"
printf '%s\n' "$out" | grep -F 'apt-get install -y omni-term-ai' >/dev/null \
    || fail "apt dry-run does not install the package"

out=$(sh "$ROOT/packaging/setup-arch.sh" --dry-run --version 0.3.0)
printf '%s\n' "$out" | grep -F 'omni-term-ai-0.3.0-1-any.pkg.tar.zst' >/dev/null \
    || fail "arch dry-run omitted the package name: $out"
printf '%s\n' "$out" | grep -F 'pacman -U' >/dev/null || fail "arch dry-run omitted pacman -U"
grep -F 'zst$/' "$ROOT/packaging/setup-arch.sh" >/dev/null \
    || fail "setup-arch would also match a .pkg.tar.zst.sig asset"

prefix=$(mktemp -d)
osr=$(mktemp)
trap 'rm -rf "$prefix" "$osr"' EXIT
printf 'ID=ubuntu\nID_LIKE=debian\n' >"$osr"

run_install() {
    OMNI_OS_RELEASE=$osr PREFIX=$prefix OMNI_DEPS_DRY=1 "$ROOT/install.sh" "$@"
}

out=$(OMNI_OS=Linux OMNI_DIST_ID=ubuntu OMNI_ID_LIKE=debian OMNI_WSL=0 run_install --package)
printf '%s\n' "$out" | grep -F 'apt-get install -y omni-term-ai' >/dev/null \
    || fail "ubuntu --package did not select apt: $out"
out=$(OMNI_OS=Linux OMNI_DIST_ID=omarchy OMNI_ID_LIKE=arch OMNI_WSL=0 run_install --package)
printf '%s\n' "$out" | grep -F 'pacman -U' >/dev/null \
    || fail "omarchy --package did not select pacman: $out"
out=$(OMNI_OS=Linux OMNI_DIST_ID=ubuntu OMNI_ID_LIKE=debian OMNI_WSL=1 run_install --deps)
printf '%s\n' "$out" | grep -F 'gnome-keyring' >/dev/null \
    || fail "WSL --deps omitted gnome-keyring: $out"
printf '%s\n' "$out" | grep -F 'dbus' >/dev/null || fail "WSL --deps omitted dbus: $out"
out=$(OMNI_OS=Linux OMNI_DIST_ID=ubuntu OMNI_ID_LIKE=debian OMNI_WSL=0 run_install --deps)
printf '%s\n' "$out" | grep -F 'gnome-keyring' >/dev/null \
    && fail "native ubuntu --deps installed gnome-keyring: $out"
if [ -n "$(ls -A "$prefix")" ]; then
    fail "dry run installed files into PREFIX"
fi

# shellcheck disable=SC1091
. "$ROOT/lib/omni.sh"
bin=$(mktemp -d)
trap 'rm -rf "$prefix" "$osr" "$bin"' EXIT
printf '%s\n' '#!/bin/sh' 'echo ran > "$OMNI_SECRET_TOOL_RAN"' >"$bin/secret-tool"
chmod 755 "$bin/secret-tool"
ran=$(mktemp)
export OMNI_SECRET_TOOL_RAN=$ran
saved_path=$PATH
PATH="$bin:/usr/bin:/bin"
export PATH
OMNI_SESSION_BUS=0
export OMNI_SESSION_BUS
backend=$(OMNI_WSL=1 omni_secret_backend)
[ "$backend" != secret-tool ] || fail "WSL without a session bus selected secret-tool"
[ ! -s "$ran" ] || fail "WSL probe executed secret-tool"
OMNI_SESSION_BUS=1
backend=$(OMNI_WSL=1 omni_secret_backend)
[ "$backend" = secret-tool ] || fail "WSL with a session bus did not select secret-tool: $backend"
backend=$(OMNI_WSL=0 omni_secret_backend)
[ "$backend" = secret-tool ] || fail "native host did not select secret-tool: $backend"
PATH=$saved_path

ver=$(tr -d '[:space:]' < "$ROOT/VERSION")
python3 - "$ROOT/package.json" "$ver" <<'PY'
import json, sys
path, ver = sys.argv[1], sys.argv[2]
doc = json.load(open(path))
assert doc["name"] == "omni-term-ai", doc["name"]
assert doc["version"] == ver, doc["version"]
bins = doc["bin"]
for name in ("launch-ai-workspace", "omni-config", "omni-secret", "omni-exec", "tmux-toggle-scratch"):
    assert name in bins, name
assert bins["omni-secret"] == "./omni-secret"
PY

if grep -F 'yay -S omni-term-ai' "$ROOT/README.md" >/dev/null; then
    fail "README still claims an AUR package"
fi
grep -F 'npm install -g github:coldcanuk/omni-term-ai' "$ROOT/README.md" >/dev/null \
    || fail "README omits the npm install"
grep -F 'make arch' "$ROOT/README.md" >/dev/null || fail "README omits make arch"
grep -F 'not written as an empty value' "$ROOT/README.md" >/dev/null \
    || fail "README still says missing keys are exported empty"
if grep -F 'omni-term-ai_0.2.1_all.deb' "$ROOT/WINDOWS_WSL.md" >/dev/null; then
    fail "WSL guide still hard-codes the 0.2.1 deb"
fi
if grep -F 'omni-secret store agy' "$ROOT/WINDOWS_WSL.md" >/dev/null; then
    fail "WSL guide still stores a nonexistent agy secret"
fi
grep -F 'signed-by=/usr/share/keyrings/omni-term-ai.gpg' "$ROOT/WINDOWS_WSL.md" >/dev/null \
    || fail "WSL guide omits the signed apt source"
grep -F 'clip.exe' "$ROOT/WINDOWS_WSL.md" >/dev/null || fail "WSL guide omits clip.exe"
grep -F 'clip.exe' "$ROOT/nvim-config/init.lua" >/dev/null || fail "init.lua omits the WSL clipboard"
grep -F 'sha256sums=('SKIP')' "$ROOT/packaging/build-arch.sh" >/dev/null \
    && fail "Arch build still skips the sha256"

if command -v npm >/dev/null 2>&1; then
    pack=$(mktemp -d)
    npx_prefix=$(mktemp -d)
    # npm pack writes the tarball in the destination and lists it on stdout.
    (cd "$ROOT" && npm pack --pack-destination "$pack" >/dev/null)
    tgz=$(find "$pack" -name 'omni-term-ai-*.tgz' -type f)
    [ -n "$tgz" ] || fail "npm pack produced no tarball"
    tar -tzf "$tgz" | grep -F 'package/omni-secret' >/dev/null \
        || fail "npm tarball dropped omni-secret (.gitignore secret*)"
    tar -tzf "$tgz" | grep -F 'package/lib/boot.sh' >/dev/null \
        || fail "npm tarball dropped lib/boot.sh"
    npm install -g --prefix "$npx_prefix" "$tgz" >/dev/null
    backend=$("$npx_prefix/bin/omni-secret" backend) || fail "npm omni-secret failed"
    case $backend in
    secret-tool | security | pass | file) ;;
    *) fail "npm omni-secret backend is '$backend'" ;;
    esac
    home=$("$npx_prefix/bin/omni-config" home) || fail "npm omni-config home failed"
    [ -f "$home/lib/omni.sh" ] || fail "npm install did not locate lib/omni.sh ($home)"
    rm -rf "$pack" "$npx_prefix"
else
    echo "npm pack: SKIP (npm not installed)"
fi

echo "install-surfaces: OK"
