#!/bin/sh
# Build and sign the apt and rpm package repositories (the gh-pages layout).
#
#   build-repo.sh DIR
#
# DIR/apt holds .deb files, DIR/rpm holds .rpm files. The signing key must
# already be in GNUPGHOME; REPO_KEY_FPR names it. Writes:
#   DIR/omni-term-ai.asc        public key, armored (dnf, rpm --import)
#   DIR/omni-term-ai.gpg        public key, binary (apt signed-by)
#   DIR/apt/Packages{,.gz} Release InRelease Release.gpg
#   DIR/rpm/*.rpm               re-signed in place
#   DIR/rpm/repodata/           regenerated; repomd.xml.asc is the signature
set -eu

dir=${1:?usage: build-repo.sh DIR}
fpr=${REPO_KEY_FPR:?REPO_KEY_FPR must name the signing key}

die() {
    echo "build-repo: $*" >&2
    exit 1
}
for t in gpg dpkg-scanpackages apt-ftparchive createrepo_c rpmsign; do
    command -v "$t" >/dev/null 2>&1 || die "$t is required"
done
gpg --batch --list-secret-keys "$fpr" >/dev/null 2>&1 || die "no secret key $fpr in ${GNUPGHOME:-~/.gnupg}"
[ -d "$dir/apt" ] || die "$dir/apt is missing"
[ -d "$dir/rpm" ] || die "$dir/rpm is missing"
dir=$(CDPATH= cd -P -- "$dir" && pwd)

sign() {
    gpg --batch --yes --pinentry-mode error --local-user "$fpr" --digest-algo SHA512 "$@"
}

gpg --batch --yes --armor --export "$fpr" >"$dir/omni-term-ai.asc"
gpg --batch --yes --export "$fpr" >"$dir/omni-term-ai.gpg"

# apt: flat repository ("deb [signed-by=...] URL/apt /").
cd "$dir/apt"
ls ./*.deb >/dev/null 2>&1 || die "no .deb files in $dir/apt"
# Old indexes and signatures must not be hashed into the new Release.
rm -f Packages Packages.gz Release Release.gpg InRelease
dpkg-scanpackages . /dev/null >Packages
gzip -9nkf Packages
rel=$(mktemp)
apt-ftparchive \
    -o APT::FTPArchive::Release::Origin=OmniTermAI \
    -o APT::FTPArchive::Release::Label=OmniTermAI \
    -o APT::FTPArchive::Release::Suite=stable \
    -o APT::FTPArchive::Release::Codename=stable \
    -o APT::FTPArchive::Release::Architectures=all \
    -o "APT::FTPArchive::Release::Description=Omni Term AI Workspace Repository" \
    release . >"$rel"
mv "$rel" Release
chmod 644 Release
sign --clearsign --output InRelease Release
sign --armor --detach-sign --output Release.gpg Release

# rpm: sign every package, then the metadata.
cd "$dir/rpm"
ls ./*.rpm >/dev/null 2>&1 || die "no .rpm files in $dir/rpm"
for p in ./*.rpm; do
    rpmsign --addsign \
        --define "_gpg_name $fpr" \
        --define "_gpg_sign_cmd_extra_args --batch --pinentry-mode error" \
        "$p" >/dev/null
done
rm -rf repodata
createrepo_c --quiet .
sign --armor --detach-sign --output repodata/repomd.xml.asc repodata/repomd.xml

echo "build-repo: signed $dir with $fpr"
