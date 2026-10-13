#!/bin/sh
# Install Omni Term AI from a source tree. Detects Ubuntu/Debian, Red Hat,
# OpenBSD, and macOS for optional dependency installation.
set -eu

ROOT=$(CDPATH= cd -P -- "$(dirname "$0")" && pwd)
PREFIX=${PREFIX:-"$HOME/.local"}
INSTALL_DEPS=0

usage() {
    echo "Usage: ./install.sh [--deps] [--prefix DIR]" >&2
    echo "  --deps     install tmux, neovim, curl, and other runtime packages" >&2
    echo "             python3 and sshfs are optional and are not installed" >&2
    echo "  --prefix   install prefix (default: \$HOME/.local)" >&2
    exit 1
}

while [ $# -gt 0 ]; do
    case $1 in
    --deps)
        INSTALL_DEPS=1
        shift
        ;;
    --prefix)
        [ $# -ge 2 ] || usage
        PREFIX=$2
        shift 2
        ;;
    --prefix=*)
        PREFIX=${1#--prefix=}
        shift
        ;;
    -h | --help)
        usage
        ;;
    *)
        usage
        ;;
    esac
done

os=${OMNI_OS:-$(uname -s)}
id_like=""
dist_id=""
# OMNI_OS_RELEASE lets tests pin the host description.
os_release=${OMNI_OS_RELEASE:-/etc/os-release}
if [ -f "$os_release" ]; then
    # shellcheck disable=SC1090
    . "$os_release"
    dist_id=${ID:-}
    id_like=${ID_LIKE:-}
fi
# Set-but-empty overrides count: OMNI_ID_LIKE= means "no ID_LIKE".
dist_id=${OMNI_DIST_ID-$dist_id}
id_like=${OMNI_ID_LIKE-$id_like}

need_root() {
    if [ "${OMNI_DEPS_DRY:-}" = 1 ]; then
        printf 'DRY %s\n' "$*"
        return 0
    fi
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    elif command -v doas >/dev/null 2>&1; then
        doas "$@"
    else
        echo "install.sh: need root to install packages (install sudo or doas)" >&2
        exit 1
    fi
}

install_deps() {
    case $os in
    Darwin)
        if ! command -v brew >/dev/null 2>&1; then
            echo "install Homebrew from https://brew.sh then re-run with --deps" >&2
            exit 1
        fi
        brew install neovim tmux git ripgrep
        ;;
    OpenBSD)
        need_root pkg_add neovim git ripgrep curl
        echo "tmux is in OpenBSD base. Store keys with: omni-secret store xai" >&2
        ;;
    FreeBSD)
        need_root pkg install -y tmux neovim git gcc gmake ripgrep unzip libsecret curl
        ;;
    Linux)
        case $dist_id in
        debian | ubuntu | pop | linuxmint)
            need_root apt-get update
            need_root apt-get install -y tmux neovim git gcc make ripgrep unzip libsecret-tools curl
            ;;
        fedora | rhel | centos | rocky | almalinux)
            if command -v dnf >/dev/null 2>&1; then
                need_root dnf install -y tmux neovim git gcc make ripgrep unzip libsecret curl
            else
                need_root yum install -y tmux neovim git gcc make ripgrep unzip libsecret curl
            fi
            ;;
        arch | omarchy | manjaro | endeavouros)
            need_root pacman -S --needed --noconfirm tmux neovim git gcc make ripgrep unzip libsecret curl
            ;;
        *)
            case $id_like in
            *debian*)
                need_root apt-get update
                need_root apt-get install -y tmux neovim git gcc make ripgrep unzip libsecret-tools curl
                ;;
            *rhel* | *fedora*)
                if command -v dnf >/dev/null 2>&1; then
                    need_root dnf install -y tmux neovim git gcc make ripgrep unzip libsecret curl
                else
                    need_root yum install -y tmux neovim git gcc make ripgrep unzip libsecret curl
                fi
                ;;
            *)
                echo "Unknown Linux ($dist_id). Install tmux neovim git gcc make ripgrep unzip curl and a secret store, then re-run without --deps." >&2
                exit 1
                ;;
            esac
            ;;
        esac
        ;;
    *)
        echo "Unsupported OS: $os" >&2
        exit 1
        ;;
    esac
}

if [ "$INSTALL_DEPS" -eq 1 ]; then
    install_deps
fi

# A dry run installs nothing, including this tree.
if [ "${OMNI_DEPS_DRY:-}" = 1 ]; then
    printf 'DRY make -C %s install PREFIX=%s\n' "$ROOT" "$PREFIX"
    exit 0
fi

make -C "$ROOT" install PREFIX="$PREFIX"
echo "Installed to $PREFIX"
echo "Ensure $PREFIX/bin is on PATH, then run: omni-secret store xai"
echo "Choose your AI assistant panes with: omni-config"
echo "Launch with: launch-ai-workspace"
