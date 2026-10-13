#!/bin/sh
# IMP-05: 0.3.0 changelog lists every merged remediation card, and
# 0.2.5 history is only extended by one line.
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
fail() { echo "FAIL: $*" >&2; exit 1; }

ver=$(tr -d '[:space:]' < "$ROOT/VERSION")
[ "$ver" = "0.3.0" ] || fail "VERSION is $ver"

body=$(mktemp)
trap 'rm -f "$body"' EXIT
awk '
    /^## 0.3.0/ { p = 1; next }
    /^## / { p = 0 }
    p { print }
' "$ROOT/CHANGELOG.md" > "$body"
[ -s "$body" ] || fail "missing 0.3.0 section"

for id in \
    BUG-01 BUG-02 BUG-03 BUG-04 BUG-05 BUG-06 BUG-07 BUG-08 BUG-09 \
    BUG-10 BUG-11 BUG-12 BUG-13 IMP-01 IMP-02 IMP-03 IMP-04 IMP-05
do
    printf '%s\n' "$(cat "$body")" | grep -F "$id" >/dev/null || fail "0.3.0 omits $id"
done

old=$(awk '
    /^## 0.2.5/ { p = 1; next }
    /^## / { p = 0 }
    p { print }
' "$ROOT/CHANGELOG.md")
printf '%s\n' "$old" | grep -F 'broken config symlink' >/dev/null \
    || fail "0.2.5 symlink note was rewritten away"
printf '%s\n' "$old" | grep -F 'covered by 0.3.0' >/dev/null \
    || fail "0.2.5 missing the one-line pointer"
# The original two notes stay. A third line is the allowed addition.
lines=$(printf '%s\n' "$old" | grep -c '^-')
[ "$lines" -eq 3 ] || fail "0.2.5 has $lines bullets, want 3"

echo "changelog-030: OK"
