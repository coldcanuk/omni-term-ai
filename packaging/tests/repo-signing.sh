#!/bin/sh
# IMP-02: the published install path verifies signatures.
# Static checks. The signing round trip runs in CI (repo-sign, verify-pages).
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
fail() {
    echo "FAIL: $*" >&2
    exit 1
}

readme=$ROOT/README.md
yml=$ROOT/.github/workflows/packages.yml
key=$ROOT/packaging/repo-signing-key.asc

# Commands only: a sources line or repo file that disables checks.
if grep -n 'deb \[[^]]*trusted=yes\|^gpgcheck=0\|^repo_gpgcheck=0' "$readme"; then
    fail "README still tells users to skip signature checks"
fi
grep -q 'signed-by=/usr/share/keyrings/omni-term-ai.gpg' "$readme" || fail "README apt line has no signed-by"
grep -q '^gpgcheck=1$' "$readme" || fail "README rpm repo has no gpgcheck=1"
grep -q '^repo_gpgcheck=1$' "$readme" || fail "README rpm repo has no repo_gpgcheck=1"

[ -f "$key" ] || fail "missing $key"
if grep -q 'PRIVATE KEY' "$key"; then
    fail "$key contains a private key"
fi

# The README fingerprint must be the committed key's fingerprint.
if command -v gpg >/dev/null 2>&1; then
    fpr=$(gpg --batch --with-colons --show-keys "$key" 2>/dev/null | awk -F: '/^fpr/ { print $10; exit }')
    [ -n "$fpr" ] || fail "cannot read $key"
    spaced=$(printf '%s' "$fpr" | sed 's/\(....\)/\1 /g; s/ $//' | awk '{ for (i = 1; i <= 10; i++) printf "%s%s", $i, (i == 5 ? "  " : (i < 10 ? " " : "")) }')
    grep -qF "$spaced" "$readme" || fail "README does not show the key fingerprint $spaced"
fi

# The workflow signs with build-repo.sh and fails without the secret.
grep -q 'sh src/packaging/build-repo.sh repo' "$yml" || fail "pages-repo does not run build-repo.sh"
grep -q 'REPO_SIGNING_KEY is not set' "$yml" || fail "pages-repo does not require REPO_SIGNING_KEY"
grep -q 'repo-client.sh' "$yml" || fail "no client verification job"

# build-repo.sh writes every signature the clients check.
for f in InRelease Release.gpg repomd.xml.asc rpmsign omni-term-ai.gpg omni-term-ai.asc; do
    grep -q "$f" "$ROOT/packaging/build-repo.sh" || fail "build-repo.sh does not produce $f"
done

echo "repo-signing: OK"
