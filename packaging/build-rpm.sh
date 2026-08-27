#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/.." && pwd)
VERSION=$(cat "$ROOT/VERSION")

if ! command -v rpmbuild >/dev/null 2>&1; then
    echo "rpmbuild is not installed; skipping RPM. Spec: packaging/rpm/omni-term-ai.spec" >&2
    echo "On Fedora/RHEL: sudo dnf install rpm-build make tar gzip" >&2
    exit 0
fi

TOP="$ROOT/dist/rpm"
rm -rf "$TOP"
mkdir -p "$TOP/BUILD" "$TOP/RPMS" "$TOP/SOURCES" "$TOP/SPECS" "$TOP/SRPMS"

sed "s/@VERSION@/$VERSION/g" "$ROOT/packaging/rpm/omni-term-ai.spec" >"$TOP/SPECS/omni-term-ai.spec"

# GNU tar --transform is used on Linux CI builders.
tar --exclude=.git --exclude=dist --exclude='*.deb' --exclude='*.rpm' \
    -czf "$TOP/SOURCES/omni-term-ai-${VERSION}.tar.gz" \
    --transform "s,^,omni-term-ai-${VERSION}/," \
    -C "$ROOT" .

rpmbuild --define "_topdir $TOP" -ba "$TOP/SPECS/omni-term-ai.spec"

find "$TOP/RPMS" -name '*.rpm' -exec cp {} "$ROOT/dist/" \;
find "$TOP/SRPMS" -name '*.rpm' -exec cp {} "$ROOT/dist/" \;
echo "RPM artifacts in $ROOT/dist"
