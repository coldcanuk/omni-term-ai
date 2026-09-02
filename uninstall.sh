#!/bin/sh
# Uninstall Omni Term AI that was manually compiled and installed.
set -eu

ROOT=$(CDPATH= cd -P -- "$(dirname "$0")" && pwd)
PREFIX=${PREFIX:-"$HOME/.local"}

usage() {
    echo "Usage: ./uninstall.sh [--prefix DIR]" >&2
    echo "  --prefix   install prefix (default: \$HOME/.local)" >&2
    exit 1
}

while [ $# -gt 0 ]; do
    case $1 in
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

make -C "$ROOT" uninstall PREFIX="$PREFIX"
echo "Uninstalled from $PREFIX"
