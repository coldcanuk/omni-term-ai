-- omni_fim: DeepSeek Fill-In-The-Middle (FIM) ghost-text completion.
--
-- Calls DeepSeek's OpenAI-compatible FIM endpoint (verified 2026-08-27):
--   POST https://api.deepseek.com/beta/completions
--     { "model": "deepseek-v4-pro",
--       "prompt": <text before cursor>,
--       "suffix": <text after cursor>,
--       "max_tokens": 128, "temperature": 0 }
-- and renders choices[0].text as inline ghost text at the cursor.
--
-- DeepSeek's FIM is its specialty: fast, cheap middle-completion for code.
-- The key comes from $DEEPSEEK_API_KEY (injected by omni-exec /
-- launch-ai-workspace from the OS secret store). Without it the plugin
-- quietly no-ops, so the Editor works even before any key is stored.
--
-- Keymaps (insert mode):
--   <Tab>  accept the ghost completion (falls through to a real Tab otherwise)
--   <C-e>  dismiss the ghost (falls through otherwise)
--
-- Usage in init.lua:
--   require('omni_fim').setup({ model = 'deepseek-v4-pro' })
--
-- SPDX-License-Identifier: GPL-3.0-or-later

local M = {}

local DEFAULTS = {
  endpoint = "https://api.deepseek.com/beta/completions",
  model = "deepseek-v4-pro", -- DeepSeek FIM works on chat models (beta API)
  max_tokens = 128, -- FIM output is capped at 4K by the API
  temperature = 0, -- deterministic completions
  debounce_ms = 120, -- pause after the last keystroke before requesting
  max_prefix_chars = 4000, -- context before the cursor (send window)
  max_suffix_chars = 2000, -- context after the cursor (send window)
  keymap_accept = "<Tab>",
  keymap_dismiss = "<C-e>",
  highlight = "OmniFimGhost", -- highlight group for the ghost text
}

local cfg = vim.deepcopy(DEFAULTS)
local ns = vim.api.nvim_create_namespace("omni_fim")

-- Runtime state: one pending request and one ghost extmark at a time.
local state = {
  timer = nil, -- debounce timer handle
  job = nil, -- curl job handle
  extmark = nil, -- ghost extmark handle
  pending = "", -- completion text to insert on accept
  warned = false, -- warned once about a missing curl binary
}

local function clear_ghost()
  if state.extmark then
    pcall(vim.api.nvim_buf_del_extmark, 0, ns, state.extmark)
    state.extmark = nil
  end
  if state.job then
    pcall(vim.fn.jobstop, state.job)
    state.job = nil
  end
  state.pending = ""
end

-- Accept the pending completion by inserting it at the current cursor.
-- The insertion is deferred with vim.schedule: nvim_buf_set_text fails with
-- "Failed to save undo information" when called from inside an expr mapping,
-- so we snapshot the text and position now and mutate the buffer later.
local function accept()
  if not state.extmark or state.pending == "" then
    return false
  end
  local text = state.pending
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  clear_ghost()
  vim.schedule(function()
    local insert = vim.split(text, "\n", { plain = true })
    local last = insert[#insert]
    vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, insert)
    -- Park the cursor at the end of the inserted text.
    vim.api.nvim_win_set_cursor(0, { row + #insert - 1, col + #last })
  end)
  return true
end

-- Render the first suggestion as overlay ghost text at the cursor.
local function show_ghost(text)
  if text == "" or vim.fn.mode():sub(1, 1) ~= "i" then
    return
  end
  clear_ghost()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  state.pending = text
  state.extmark = vim.api.nvim_buf_set_extmark(0, ns, row - 1, col, {
    virt_text = { { text, cfg.highlight } },
    virt_text_pos = "overlay",
    hl_mode = "combine",
  })
end

local function fetch()
  local key = vim.env.DEEPSEEK_API_KEY
  if not key or key == "" then
    return -- no key stored yet; stay quiet
  end
  if vim.bo.filetype == "" or not vim.bo.modifiable then
    return
  end
  if vim.fn.executable("curl") == 0 then
    if not state.warned then
      state.warned = true
      vim.notify("omni_fim: curl is required for DeepSeek FIM", vim.log.levels.WARN)
    end
    return
  end

  -- Gather the prefix (text before the cursor) and suffix (after it).
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local prefix_parts, suffix_parts = {}, {}
  for i = 1, row do
    local l = lines[i] or ""
    prefix_parts[#prefix_parts + 1] = i == row and l:sub(1, col) or l
  end
  local tail = lines[row] or ""
  suffix_parts[1] = tail:sub(col + 1)
  for i = row + 1, #lines do
    suffix_parts[#suffix_parts + 1] = lines[i]
  end
  local prefix = table.concat(prefix_parts, "\n")
  local suffix = table.concat(suffix_parts, "\n")
  if #prefix > cfg.max_prefix_chars then
    prefix = prefix:sub(#prefix - cfg.max_prefix_chars)
  end
  if #suffix > cfg.max_suffix_chars then
    suffix = suffix:sub(1, cfg.max_suffix_chars)
  end

  local payload = vim.json.encode({
    model = cfg.model,
    prompt = prefix,
    suffix = suffix,
    max_tokens = cfg.max_tokens,
    temperature = cfg.temperature,
  })
  local tmp = vim.fn.tempname()
  local f = io.open(tmp, "w")
  if not f then
    return
  end
  f:write(payload)
  f:close()

  state.job = vim.fn.jobstart({
    "curl", "-sS", "--max-time", "20", cfg.endpoint,
    "-H", "Authorization: Bearer " .. key,
    "-H", "Content-Type: application/json",
    "-d", "@" .. tmp,
  }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if not data or #data == 0 then
        return
      end
      local ok, decoded = pcall(vim.json.decode, table.concat(data, "\n"))
      if not ok or not decoded or not decoded.choices or #decoded.choices == 0 then
        return
      end
      local suggestion = decoded.choices[1].text or ""
      -- Trim trailing whitespace only. Leading whitespace is significant:
      -- a leading newline means the completion starts on the next line, and
      -- leading spaces may be real indentation for a continued line.
      suggestion = suggestion:gsub("%s+$", "")
      vim.schedule(function()
        show_ghost(suggestion)
      end)
    end,
    on_exit = function()
      state.job = nil
    end,
  })
end

-- Debounce: restart the timer on every keystroke, fetch when typing pauses.
local function schedule_fetch()
  if state.timer then
    vim.fn.timer_stop(state.timer)
  end
  state.timer = vim.fn.timer_start(cfg.debounce_ms, function()
    if vim.fn.mode():sub(1, 1) == "i" then
      fetch()
    end
  end)
end

local function setup(opts)
  cfg = vim.tbl_deep_extend("force", cfg, opts or {})

  vim.api.nvim_set_hl(0, cfg.highlight, { link = "Comment" })

  -- <Tab>: accept when a ghost is pending, otherwise fall through.
  vim.keymap.set("i", cfg.keymap_accept, function()
    if accept() then
      return ""
    end
    return "<Tab>"
  end, { expr = true, desc = "omni_fim: accept completion" })

  -- <C-e>: dismiss the ghost, otherwise fall through.
  vim.keymap.set("i", cfg.keymap_dismiss, function()
    if state.extmark then
      clear_ghost()
      return ""
    end
    return nil -- fall through to the default <C-e> behavior
  end, { expr = true, desc = "omni_fim: dismiss completion" })

  vim.api.nvim_create_autocmd("InsertEnter", {
    callback = schedule_fetch,
    desc = "omni_fim: fetch on insert enter",
  })
  vim.api.nvim_create_autocmd("TextChangedI", {
    callback = schedule_fetch,
    desc = "omni_fim: fetch on insert text change",
  })
  vim.api.nvim_create_autocmd("CursorMovedI", {
    callback = clear_ghost,
    desc = "omni_fim: drop stale ghost on cursor move",
  })
  vim.api.nvim_create_autocmd("InsertLeave", {
    callback = clear_ghost,
    desc = "omni_fim: drop ghost on insert leave",
  })
end

M.setup = setup
return M
