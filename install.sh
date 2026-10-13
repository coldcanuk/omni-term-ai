#!/bin/sh
# Install Omni Term AI from a source tree, or install the distro package.
# Detects Ubuntu/Debian (including WSL), Red Hat, Arch/Omarchy, FreeBSD,
# OpenBSD, and macOS for optional dependency installation.
set -eu

ROOT=$(CDPATH= cd -P -- "$(dirname "$0")" && pwd)
PREFIX=${PREFIX:-"$HOME/.local"}
INSTALL_DEPS=0
INSTALL_PACKAGE=0

usage() {
    echo "Usage: ./install.sh [--deps] [--package] [--prefix DIR]" >&2
    echo "  --deps     install tmux, neovim, curl, and other runtime packages" >&2
    echo "             python3 and sshfs are optional and are not installed" >&2
    echo "             on WSL, also installs dbus and gnome-keyring" >&2
    echo "  --package  install the distro package (apt on Debian/Ubuntu/WSL," >&2
    echo "             pacman on Arch/Omarchy) instead of this source tree" >&2
    echo "  --prefix   install prefix for a source install (default: \$HOME/.local)" >&2
    exit 1
}

while [ $# -gt 0 ]; do
    case $1 in
    --deps)
        INSTALL_DEPS=1
        shift
        ;;
    --package)
        INSTALL_PACKAGE=1
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

# OMNI_WSL=1 forces WSL behavior. OMNI_WSL=0 forces a native host.
is_wsl() {
    case ${OMNI_WSL-} in
    1) return 0 ;;
    0) return 1 ;;
    esac
    if [ -n "${WSL_DISTRO_NAME:-}" ] || [ -n "${WSL_INTEROP:-}" ]; then
        return 0
    fi
    if [ -r /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; then
        return 0
    fi
    return 1
}

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

apt_deps() {
    need_root apt-get update
    if is_wsl; then
        need_root apt-get install -y tmux neovim git gcc make ripgrep unzip libsecret-tools curl dbus gnome-keyring
    else
        need_root apt-get install -y tmux neovim git gcc make ripgrep unzip libsecret-tools curl
    fi
}

pacman_deps() {
    if is_wsl; then
        need_root pacman -S --needed --noconfirm tmux neovim git gcc make ripgrep unzip libsecret curl dbus gnome-keyring
    else
        need_root pacman -S --needed --noconfirm tmux neovim git gcc make ripgrep unzip libsecret curl
    fi
}

install_package() {
    dry=0
    if [ "${OMNI_DEPS_DRY:-}" = 1 ]; then
        dry=1
    fi
    case $os in
    Linux)
        case $dist_id in
        debian | ubuntu | pop | linuxmint)
            family=apt
            ;;
        arch | omarchy | manjaro | endeavouros)
            family=arch
            ;;
        *)
            case $id_like in
            *debian*) family=apt ;;
            *arch*) family=arch ;;
            *)
                echo "install.sh: no package for $dist_id. Re-run without --package." >&2
                exit 1
                ;;
            esac
            ;;
        esac
        ;;
    *)
        echo "install.sh: --package is not implemented for $os" >&2
        exit 1
        ;;
    esac
    if [ "$family" = apt ]; then
        if [ "$dry" -eq 1 ]; then
            sh "$ROOT/packaging/setup-apt.sh" --dry-run
        else
            sh "$ROOT/packaging/setup-apt.sh"
        fi
    else
        if [ "$dry" -eq 1 ]; then
            sh "$ROOT/packaging/setup-arch.sh" --dry-run
        else
            sh "$ROOT/packaging/setup-arch.sh"
        fi
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
            apt_deps
            ;;
        fedora | rhel | centos | rocky | almalinux)
            if command -v dnf >/dev/null 2>&1; then
                need_root dnf install -y tmux neovim git gcc make ripgrep unzip libsecret curl
            else
                need_root yum install -y tmux neovim git gcc make ripgrep unzip libsecret curl
            fi
            ;;
        arch | omarchy | manjaro | endeavouros)
            pacman_deps
            ;;
        *)
            case $id_like in
            *debian*)
                apt_deps
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

if [ "$INSTALL_PACKAGE" -eq 1 ]; then
    install_package
    exit 0
fi

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
if is_wsl; then
    echo "WSL: if omni-secret store hangs, the session bus is down."
    echo "  sudo service dbus start && eval \"\$(gnome-keyring-daemon --start)\""
    echo "  or: OMNI_SECRET_BACKEND=file omni-secret store xai"
fi
