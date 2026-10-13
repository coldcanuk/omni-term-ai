#!/bin/sh
# IMP-06: init.lua prefers vim.uv, and :Neotree stays defined before -c.
# -c runs before VimEnter. A command created only on VimEnter is E492.
# neo-tree is a start plugin, so lazy defines the command during setup().
set -eu
ROOT=$(CDPATH= cd -P -- "$(dirname "$0")/../.." && pwd)
fail() { echo "FAIL: $*" >&2; exit 1; }
command -v nvim >/dev/null 2>&1 || { echo "nvim-startup: SKIP (no nvim)"; exit 77; }

init="$ROOT/nvim-config/init.lua"
grep -F 'vim.uv or vim.loop' "$init" >/dev/null || fail "init.lua must prefer vim.uv with a vim.loop fallback"
if grep -n 'vim\.loop\.' "$init"; then
    fail "init.lua still calls vim.loop directly"
fi

block=$(mktemp)
early=$(mktemp)
late=$(mktemp)
trap 'rm -f "$block" "$early" "$late"' EXIT

awk '
    /nvim-neo-tree\/neo-tree.nvim/ { p = 1 }
    p && /Fuzzy Finder/ { exit }
    p { print }
' "$init" > "$block"
[ -s "$block" ] || fail "neo-tree spec not found"
if grep -E 'lazy[[:space:]]*=[[:space:]]*true|^[[:space:]]*(cmd|event|keys|ft)[[:space:]]*=' "$block"; then
    fail "neo-tree is deferred; nvim -c Neotree would run before the command exists"
fi

cat > "$early" <<'EOF'
vim.api.nvim_create_user_command("Neotree", function() end, {})
EOF
nvim --headless -u NONE --cmd "luafile $early" -c 'Neotree show' -c qa >/dev/null 2>&1 \
    || fail "command defined during init was not available to -c"

cat > "$late" <<'EOF'
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.api.nvim_create_user_command("Neotree", function() end, {})
  end,
})
EOF
late_out=$(nvim --headless -u NONE --cmd "luafile $late" -c 'Neotree show' -c qa 2>&1 || true)
printf '%s\n' "$late_out" | grep -F 'E492' >/dev/null \
    || fail "VimEnter-only command should be E492 under -c: $late_out"

dep=$(nvim --headless -u NONE -c 'lua
local notes = {}
vim.notify = function(msg) notes[#notes + 1] = tostring(msg) end
local uv = vim.uv or vim.loop
assert(uv and uv.fs_stat, "no uv")
local _ = uv.fs_stat("/")
local joined = table.concat(notes, "\n")
if joined:lower():find("deprecat") then
  error("uv deprecation: " .. joined)
end
print("nvim-startup: uv-ok")
' -c qa 2>&1) || fail "nvim uv probe failed: $dep"
printf '%s\n' "$dep" | grep -F 'nvim-startup: uv-ok' >/dev/null || fail "missing uv-ok: $dep"
printf '%s\n' "$dep" | grep -F 'vim.loop' >/dev/null && fail "vim.loop deprecation: $dep" || true

echo "nvim-startup: OK"
