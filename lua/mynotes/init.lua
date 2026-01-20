local M = {}

M.config = {
  -- Persistent notes file (cross-platform)
  filepath = vim.fn.stdpath("data") .. "/mynotes.md",

  -- Reuse the same buffer if it is already loaded
  reuse_existing_buffer = true,

  -- Floating window sizing (relative to editor size)
  width_ratio = 0.78,
  height_ratio = 0.78,

  -- Window border: "single" | "double" | "rounded" | "solid" | "shadow" | nil
  border = "rounded",

  -- Keymap to open the notes
  keymap_open = "<leader>\\",

  -- Default content if the file doesn't exist yet
  default_template = table.concat({
    "# My notes example",
    "",
    "## Navigation",
    "- w / b / e: ...",
    "",
    "## Editing",
    "- ciw: ...",
    "",
    "## Search",
    "- /: ...",
    "",
    "## Plugins / misc",
    "- ...",
    "",
  }, "\n"),
}

local state = { win = nil, buf = nil }

-- -------------------------
-- File / buffer helpers
-- -------------------------
local function file_exists(path)
  return vim.fn.filereadable(path) == 1
end

local function ensure_parent_dir(path)
  local dir = vim.fn.fnamemodify(path, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end

local function ensure_file(path, template)
  if file_exists(path) then return end
  ensure_parent_dir(path)
  local fd = io.open(path, "w")
  if not fd then
    vim.notify("mynotes: could not create file: " .. path, vim.log.levels.ERROR)
    return
  end
  fd:write(template or "")
  fd:close()
end

local function find_existing_buf(path)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.api.nvim_buf_get_name(bufnr) == path then
      return bufnr
    end
  end
  return nil
end

-- -------------------------
-- Floating window helpers
-- -------------------------
local function float_geometry(cfg)
  local columns, lines = vim.o.columns, vim.o.lines
  local width = math.floor(columns * cfg.width_ratio)
  local height = math.floor(lines * cfg.height_ratio)

  if width < 60 then width = math.min(columns - 4, 60) end
  if height < 15 then height = math.min(lines - 4, 15) end

  local row = math.floor((lines - height) / 2) - 1
  local col = math.floor((columns - width) / 2)
  if row < 0 then row = 0 end
  if col < 0 then col = 0 end

  return width, height, row, col
end

local function close_win(winid)
  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_close(winid, true)
  end
end

local function set_close_mappings(bufnr, winid)
  vim.keymap.set("n", "q", function() close_win(winid) end, { buffer = bufnr, silent = true })
  vim.keymap.set("n", "<Esc>", function() close_win(winid) end, { buffer = bufnr, silent = true })
end

local function get_real_display_path(path)
  local resolved = vim.fn.resolve(path)
  return vim.fn.fnamemodify(resolved, ":~")
end

local function build_title(path)
  local title = get_real_display_path(path)
  return "  " .. title .. "  "
end

local function open_notes_float(path, cfg)
  local width, height, row, col = float_geometry(cfg)

  local title = build_title(cfg.filepath)

  local bufnr = cfg.reuse_existing_buffer and find_existing_buf(path) or nil
  if not bufnr then
    bufnr = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(bufnr, path)
  end

  local winid = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = cfg.border,

    title = title,
    title_pos = "center",
  })

  vim.api.nvim_set_current_buf(bufnr)
  vim.cmd("silent keepalt edit " .. vim.fn.fnameescape(path))

  vim.bo.filetype = "markdown"
  vim.bo.bufhidden = "hide"
  vim.bo.swapfile = false
  vim.wo.wrap = true
  vim.wo.conceallevel = 2

  set_close_mappings(bufnr, winid)

  state.win = winid
  state.buf = bufnr
end

function M.open()
  local cfg = M.config
  ensure_file(cfg.filepath, cfg.default_template)

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    return
  end

  open_notes_float(cfg.filepath, cfg)
end

function M.setup(opts)
  if vim.fn.has("nvim-0.11") ~= 1 then
    vim.notify("mynotes.nvim requires Neovim >= 0.11.0", vim.log.levels.ERROR)
    return
  end

  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  vim.keymap.set("n", M.config.keymap_open, function()
    M.open()
  end, { desc = "Open mynotes (floating window)" })

  vim.api.nvim_create_user_command("MyNotes", function()
    M.open()
  end, {})
end

return M
