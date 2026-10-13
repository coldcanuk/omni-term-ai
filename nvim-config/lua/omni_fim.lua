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
  generation = 0, -- request stamp; older callbacks must not paint
}

local function bump_generation()
  state.generation = (state.generation or 0) + 1
  return state.generation
end

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
  bump_generation()
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
    vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, insert)
    -- A multi-line insert starts later lines at column 0. Do not add `col`.
    local cursor_row, cursor_col = M.accept_cursor(row, col, text)
    vim.api.nvim_win_set_cursor(0, { cursor_row, cursor_col })
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
  if vim.g.loaded_copilot or vim.g.loaded_copilot_lua then
    return -- bail out to prevent ghost text conflicts with Copilot plugins
  end

  local endpoint = cfg.endpoint
  local model = cfg.model
  local auth_header = ""
  local azure_key = vim.env.AZURE_OPENAI_API_KEY
  local azure_endpoint = vim.env.AZURE_OPENAI_ENDPOINT
  local azure_deployment = vim.env.AZURE_OPENAI_DEPLOYMENT
  local openai_key = vim.env.OPENAI_API_KEY
  local deepseek_key = vim.env.DEEPSEEK_API_KEY
  local provider = vim.env.OMNI_FIM_PROVIDER or "deepseek"

  if provider == "azure" then
    if not (azure_key and azure_key ~= "" and azure_endpoint and azure_endpoint ~= "" and azure_deployment and azure_deployment ~= "") then
      return
    end
    endpoint = azure_endpoint:gsub("/$", "") .. "/openai/deployments/" .. azure_deployment .. "/completions?api-version=2024-02-15-preview"
    auth_header = "api-key: " .. azure_key
  elseif provider == "openai" then
    if not (openai_key and openai_key ~= "") then
      return
    end
    endpoint = "https://api.openai.com/v1/completions"
    model = "gpt-3.5-turbo-instruct"
    auth_header = "Authorization: Bearer " .. openai_key
  else
    if not (deepseek_key and deepseek_key ~= "") then
      return
    end
    auth_header = "Authorization: Bearer " .. deepseek_key
  end


  if vim.bo.filetype == "" or not vim.bo.modifiable then
    return
  end
  if vim.fn.executable("curl") == 0 then
    if not state.warned then
      state.warned = true
      vim.notify("omni_fim: curl is required for FIM", vim.log.levels.WARN)
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
    model = model,
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

  local stamp = bump_generation()
  state.job = vim.fn.jobstart({
    "curl", "-sS", "--max-time", "20", endpoint,
    "-H", auth_header,
    "-H", "Content-Type: application/json",
    "-d", "@" .. tmp,
  }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if stamp ~= state.generation then
        return
      end
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
      local shown = M.consider(stamp, suggestion)
      if not shown then
        return
      end
      vim.schedule(function()
        if stamp ~= state.generation then
          return
        end
        show_ghost(shown)
      end)
    end,
    on_exit = function()
      M.finish_request(tmp)
      if stamp == state.generation then
        state.job = nil
      end
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

function M.endpoint_for(env)
  env = env or vim.env
  local provider = env.OMNI_FIM_PROVIDER or "deepseek"
  if provider == "azure" then
    if not (env.AZURE_OPENAI_API_KEY and env.AZURE_OPENAI_API_KEY ~= ""
        and env.AZURE_OPENAI_ENDPOINT and env.AZURE_OPENAI_ENDPOINT ~= ""
        and env.AZURE_OPENAI_DEPLOYMENT and env.AZURE_OPENAI_DEPLOYMENT ~= "") then
      return nil
    end
    return (env.AZURE_OPENAI_ENDPOINT:gsub("/$", ""))
      .. "/openai/deployments/" .. env.AZURE_OPENAI_DEPLOYMENT
      .. "/completions?api-version=2024-02-15-preview"
  elseif provider == "openai" then
    if not (env.OPENAI_API_KEY and env.OPENAI_API_KEY ~= "") then
      return nil
    end
    return "https://api.openai.com/v1/completions"
  end
  if not (env.DEEPSEEK_API_KEY and env.DEEPSEEK_API_KEY ~= "") then
    return nil
  end
  return "https://api.deepseek.com/beta/completions"
end

function M.accept_cursor(row, col, text)
  local insert = vim.split(text, "\n", { plain = true })
  local last = insert[#insert] or ""
  local cursor_row = row + #insert - 1
  local cursor_col = (#insert > 1) and #last or (col + #last)
  return cursor_row, cursor_col
end

function M.consider(stamp, text)
  if stamp ~= state.generation then
    return nil
  end
  return text
end

function M.finish_request(path)
  if path and path ~= "" then
    os.remove(path)
  end
end

function M._test_begin()
  return bump_generation()
end

return M
