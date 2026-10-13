#!/bin/sh
# IMP-03: package metadata lists curl, and the bashrc snippet follows
# the installed share directory instead of a hard-coded ~/.local path.
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
fail() { echo "FAIL: $*" >&2; exit 1; }

depends=$(sed -n 's/^Depends: //p' "$ROOT/packaging/deb/control")
printf '%s\n' "$depends" | grep -F curl >/dev/null || fail "deb control omits curl: $depends"
printf '%s\n' "$depends" | grep -F python3 >/dev/null && fail "python3 must stay optional in deb Depends"
printf '%s\n' "$depends" | grep -F sshfs >/dev/null && fail "sshfs must stay optional in deb Depends"
grep -F 'Suggests: python3, sshfs' "$ROOT/packaging/deb/control" >/dev/null || fail "deb does not suggest python3 and sshfs"

grep -F "depends=('neovim' 'tmux' 'git' 'ripgrep' 'curl')" "$ROOT/packaging/build-arch.sh" >/dev/null \
    || fail "PKGBUILD omits curl"
grep -F "optdepends=('python: bash FIM completion' 'sshfs: jumpbox remote targets')" "$ROOT/packaging/build-arch.sh" >/dev/null \
    || fail "PKGBUILD does not mark python and sshfs optional"
grep -F 'Requires:       curl' "$ROOT/packaging/rpm/omni-term-ai.spec" >/dev/null || fail "rpm omits curl"
grep -F azure "$ROOT/Formula/omni-term-ai.rb" >/dev/null || fail "Homebrew caveats omit azure"

if grep -F '$HOME/.local/share/omni-term-ai/lib/omni-bash.sh' "$ROOT/README.md"; then
    fail "README still hard-codes the bashrc path"
fi
grep -F '. "$(omni-config home)/lib/omni-bash.sh"' "$ROOT/README.md" >/dev/null \
    || fail "README snippet does not use omni-config home"

stage=$(mktemp -d)
stub=$(mktemp -d)
trap 'rm -rf "$stage" "$stub"' EXIT
printf '%s\n' '#!/bin/sh' 'exit 1' > "$stub/secret-tool"
chmod +x "$stub/secret-tool"
make -C "$ROOT" install PREFIX="$stage/usr/local" >/dev/null
home=$("$stage/usr/local/bin/omni-config" home)
[ "$home" = "$stage/usr/local/share/omni-term-ai" ] || fail "home is $home"
[ -f "$home/lib/omni-bash.sh" ] || fail "installed bash lib missing"

got=$(
    env -i \
        HOME="${HOME:-/tmp}" \
        PATH="$stage/usr/local/bin:$stub:/usr/bin:/bin" \
        TERM=xterm \
        bash --noprofile --norc -c '. "$(omni-config home)/lib/omni-bash.sh"; printf "%s\n" "$OMNI_TERM_AI_HOME"'
) || fail "bashrc snippet did not source"
[ "$got" = "$home" ] || fail "snippet home is $got"

echo "package-deps: OK"
