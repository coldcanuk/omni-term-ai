#!/bin/sh
# Use a published package repo the way a user would, with signatures enforced.
#
#   repo-client.sh BASE_URL [FINGERPRINT]
#
# BASE_URL is the repo root (https://coldcanuk.github.io/omni-term-ai, or a
# local http server over a build-repo.sh tree). FINGERPRINT, if given, must
# match the published key.
#
# apt runs on this host (needs sudo; Debian/Ubuntu). dnf runs in a Fedora
# container (needs docker). Run it on a throwaway CI host: it changes apt
# state.
set -eu

base=${1:?usage: repo-client.sh BASE_URL [FINGERPRINT]}
want=${2:-}

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# apt reads the keyring as user _apt.
chmod 755 "$work"

curl -fsSL "$base/omni-term-ai.gpg" -o "$work/key.gpg"
chmod 644 "$work/key.gpg"
got=$(gpg --batch --with-colons --show-keys "$work/key.gpg" | awk -F: '/^fpr/ { print $10; exit }')
[ -n "$got" ] || fail "no key at $base/omni-term-ai.gpg"
if [ -n "$want" ] && [ "$got" != "$want" ]; then
    fail "published key is $got, want $want"
fi
echo "repo-client: key $got"

# --- apt -------------------------------------------------------------------
mkdir -m 755 "$work/parts"

# Only this source, for update, policy, and download alike.
apt_only() {
    "$@" -o Dir::Etc::SourceList="$work/omni.list" -o Dir::Etc::SourceParts="$work/parts"
}

apt_update() {
    # $1 = keyring. Warnings are errors.
    echo "deb [signed-by=$1] $base/apt /" >"$work/omni.list"
    chmod 644 "$work/omni.list"
    apt_only sudo apt-get update --error-on=any
}

apt_update "$work/key.gpg" || fail "apt-get update rejected the signed repo"
apt_only apt-cache policy omni-term-ai | tee "$work/policy"
grep -q 'Candidate: [0-9]' "$work/policy" || fail "apt has no candidate"
(cd "$work" && apt_only apt-get download omni-term-ai) || fail "apt-get download failed"
ls "$work"/omni-term-ai_*_all.deb >/dev/null || fail "no .deb downloaded"

# Negative: a different key must be refused.
GNUPGHOME=$work/wrong
export GNUPGHOME
mkdir -m 700 "$GNUPGHOME"
gpg --batch --quiet --passphrase '' --quick-gen-key 'wrong key <wrong@invalid>' ed25519 sign 1d
gpg --batch --export >"$work/wrong.gpg"
chmod 644 "$work/wrong.gpg"
unset GNUPGHOME
if apt_update "$work/wrong.gpg" >"$work/wrong.log" 2>&1; then
    cat "$work/wrong.log" >&2
    fail "apt accepted the repo with the wrong key"
fi
grep -q 'NO_PUBKEY\|not signed\|signature' "$work/wrong.log" || {
    cat "$work/wrong.log" >&2
    fail "wrong-key failure was not a signature error"
}
echo "repo-client: apt OK (signed-by enforced, wrong key refused)"

# --- dnf -------------------------------------------------------------------
docker run --rm --network host -e BASE="$base" fedora:latest sh -euc '
cat >/etc/yum.repos.d/omni-term-ai.repo <<EOF
[omni-term-ai]
name=Omni Term AI Repository
baseurl=$BASE/rpm
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$BASE/omni-term-ai.asc
EOF
dnf -y -q --repo=omni-term-ai makecache
mkdir /tmp/d
dnf -y -q --repo=omni-term-ai download --destdir=/tmp/d omni-term-ai
curl -fsSL "$BASE/omni-term-ai.asc" -o /tmp/key.asc
rpm --import /tmp/key.asc
for p in /tmp/d/*.rpm; do
    out=$(rpm -K "$p")
    echo "$out"
    case $out in
    *"signatures OK"*) ;;
    *) echo "FAIL: $p is not signed by the repo key" >&2; exit 1 ;;
    esac
done
' || fail "dnf rejected the signed repo"
echo "repo-client: dnf OK (repo_gpgcheck and gpgcheck enforced)"
echo "repo-client: OK ($base)"
