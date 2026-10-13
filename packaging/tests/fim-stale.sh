#!/bin/sh
# BUG-09: a stale FIM response must not paint, the payload must be removed,
# and a two-line accept must not add the old column to the last line.
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
fail() { echo "FAIL: $*" >&2; exit 1; }
command -v nvim >/dev/null 2>&1 || fail "nvim is required (CI installs it)"

out=$(nvim --headless -u NONE --cmd "set rtp^=$ROOT/nvim-config" -c 'lua
local M = require("omni_fim")
local row, col = M.accept_cursor(1, 4, "ab\ncd")
assert(row == 2 and col == 2, "multiline cursor " .. row .. "," .. col)
local row1, col1 = M.accept_cursor(3, 5, "xyz")
assert(row1 == 3 and col1 == 8, "single cursor " .. row1 .. "," .. col1)
local old = M._test_begin()
local new = M._test_begin()
assert(M.consider(old, "stale") == nil, "stale response painted")
assert(M.consider(new, "fresh") == "fresh", "latest response dropped")
local tmp = vim.fn.tempname()
local f = io.open(tmp, "w")
f:write("payload")
f:close()
M.finish_request(tmp)
assert(io.open(tmp, "r") == nil, "payload file left behind")
print("fim-stale: OK")
' -c qa 2>&1) || fail "nvim failed: $out"
printf '%s\n' "$out" | grep -F 'fim-stale: OK' >/dev/null || fail "missing ok: $out"
echo "fim-stale: OK"
