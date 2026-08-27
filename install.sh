#!/bin/sh
# Install Omni Term AI from a source tree. Detects Ubuntu/Debian, Red Hat,
# OpenBSD, and macOS for optional dependency installation.
set -eu

ROOT=$(CDPATH= cd -P -- "$(dirname "$0")" && pwd)
PREFIX=${PREFIX:-"$HOME/.local"}
INSTALL_DEPS=0

usage() {
    echo "Usage: ./install.sh [--deps] [--prefix DIR]" >&2
    echo "  --deps     install tmux, neovim, and other runtime packages" >&2
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

os=$(uname -s)
id_like=""
dist_id=""
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    dist_id=${ID:-}
    id_like=${ID_LIKE:-}
fi

need_root() {
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
        need_root pkg_add neovim git ripgrep
        echo "tmux is in OpenBSD base. Store keys with: omni-secret store xai" >&2
        ;;
    Linux)
        case $dist_id in
        debian | ubuntu | pop | linuxmint)
            need_root apt-get update
            need_root apt-get install -y tmux neovim git gcc make ripgrep unzip libsecret-tools
            ;;
        fedora | rhel | centos | rocky | almalinux)
            if command -v dnf >/dev/null 2>&1; then
                need_root dnf install -y tmux neovim git gcc make ripgrep unzip libsecret
            else
                need_root yum install -y tmux neovim git gcc make ripgrep unzip libsecret
            fi
            ;;
        *)
            case $id_like in
            *debian*)
                need_root apt-get update
                need_root apt-get install -y tmux neovim git gcc make ripgrep unzip libsecret-tools
                ;;
            *rhel* | *fedora*)
                if command -v dnf >/dev/null 2>&1; then
                    need_root dnf install -y tmux neovim git gcc make ripgrep unzip libsecret
                else
                    need_root yum install -y tmux neovim git gcc make ripgrep unzip libsecret
                fi
                ;;
            *)
                echo "Unknown Linux ($dist_id). Install tmux neovim git gcc make ripgrep unzip and a secret store, then re-run without --deps." >&2
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

make -C "$ROOT" install PREFIX="$PREFIX"
echo "Installed to $PREFIX"
echo "Ensure $PREFIX/bin is on PATH, then run: omni-secret store xai"
echo "Choose your AI assistant panes with: omni-config"
echo "Launch with: launch-ai-workspace"
