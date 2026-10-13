#!/bin/sh
# Attach the Arch package and npm tarball to an existing GitHub release.
# The packages workflow publishes .deb, .rpm, and .pkg on a v* tag. It cannot
# be extended here: the publish token has repo scope but not workflow scope.
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
tag=${1:-}
if [ -z "$tag" ]; then
    tag=v$(tr -d '[:space:]' < "$ROOT/VERSION")
fi

sh "$ROOT/packaging/build-arch.sh"
npm pack --pack-destination "$ROOT/dist"

pkg=$(find "$ROOT/dist" -maxdepth 1 -name 'omni-term-ai-*.pkg.tar.*' -type f | head -n 1)
tgz=$(find "$ROOT/dist" -maxdepth 1 -name 'omni-term-ai-*.tgz' -type f | head -n 1)
[ -n "$pkg" ] && [ -f "$pkg" ] || {
    echo "attach-release-extras: no Arch package in dist/" >&2
    exit 1
}
[ -n "$tgz" ] && [ -f "$tgz" ] || {
    echo "attach-release-extras: no npm tarball in dist/" >&2
    exit 1
}

gh release upload "$tag" "$pkg" "$tgz" --clobber
echo "uploaded $(basename "$pkg") and $(basename "$tgz") to $tag"
