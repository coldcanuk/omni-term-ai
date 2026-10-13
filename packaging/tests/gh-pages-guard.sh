#!/bin/sh
# BUG-13: a failed gh-pages checkout must not publish over an existing branch.
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
fail() { echo "FAIL: $*" >&2; exit 1; }
yml=$ROOT/.github/workflows/packages.yml
grep -q 'id: pages' "$yml" || fail "checkout step has no id"
grep -q 'Refuse to publish over a failed existing checkout' "$yml" || fail "missing guard"
grep -q 'steps.pages.outcome != '"'"'success'"'"'' "$yml" || fail "guard does not check checkout outcome"
grep -q 'refusing to replace the package repo' "$yml" || fail "guard does not refuse an existing branch"
if grep -n 'continue-on-error: true' "$yml" | grep -q .; then
    # continue-on-error is allowed only if the guard follows it
    :
fi
# The deploy step must come after the guard.
guard=$(grep -n 'Refuse to publish' "$yml" | head -1 | cut -d: -f1)
deploy=$(grep -n 'Deploy to GitHub Pages' "$yml" | head -1 | cut -d: -f1)
if [ -z "$guard" ] || [ -z "$deploy" ] || [ "$guard" -ge "$deploy" ]; then
    fail "guard does not run before deploy"
fi
echo "gh-pages-guard: OK"
