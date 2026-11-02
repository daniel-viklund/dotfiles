-- Persistent terminal buffers in one bottom panel per editor tab.
local M = {}
local api = vim.api
local entries, panels = {}, {}
local shell_count = 0
local next_id = 1

local function header_highlights()
  local background = api.nvim_get_hl(0, { name = "Normal", link = false }).bg or "NONE"
  for target, source in pairs({
    TerminalPanelBar = "WinBar",
    TerminalPanelTab = "TabLine",
    TerminalPanelTabSelected = "TabLineSel",
  }) do
    local highlight = api.nvim_get_hl(0, { name = source, link = false })
    highlight.bg = background
    highlight.ctermbg = nil
    highlight.reverse = false
    api.nvim_set_hl(0, target, highlight)
  end
end

local function valid(term)
  return term and term.bufnr and api.nvim_buf_is_valid(term.bufnr)
end

local function panel(tab)
  tab = tab or api.nvim_get_current_tabpage()
  panels[tab] = panels[tab] or {}
  return panels[tab]
end

local function visible(p)
  return p.window and api.nvim_win_is_valid(p.window)
    and valid(p.selected) and api.nvim_win_get_buf(p.window) == p.selected.bufnr
end

local function close_window(p)
  local tab = api.nvim_win_get_tabpage(p.window)
  if #api.nvim_tabpage_list_wins(tab) == 1 then
    api.nvim_win_set_buf(p.window, api.nvim_create_buf(true, false))
  else
    api.nvim_win_close(p.window, true)
  end
end

function M.all()
  -- Include externally opened ToggleTerm shells, but keep our own references to
  -- finished jobs because ToggleTerm removes them from its registry on exit.
  for _, term in ipairs(require("toggleterm.terminal").get_all(true)) do
    if not vim.tbl_contains(entries, term) then entries[#entries + 1] = term end
  end
  entries = vim.tbl_filter(valid, entries)
  return vim.list_slice(entries)
end

local function label(term)
  local name = term.display_name or ("Shell " .. term.id)
  if term.panel_exit_code ~= nil then name = name .. " [exit " .. term.panel_exit_code .. "]" end
  return name
end

function M.refresh()
  local all = M.all()
  for tab, p in pairs(panels) do
    if not api.nvim_tabpage_is_valid(tab) then
      panels[tab] = nil
    elseif visible(p) then
      local highlights = {}
      for mapping in vim.wo[p.window].winhighlight:gmatch("[^,]+") do
        if not mapping:match("^WinBar:") and not mapping:match("^WinBarNC:") then
          highlights[#highlights + 1] = mapping
        end
      end
      highlights[#highlights + 1] = "WinBar:TerminalPanelBar"
      highlights[#highlights + 1] = "WinBarNC:TerminalPanelBar"
      vim.wo[p.window].winhighlight = table.concat(highlights, ",")
      local tabs = {}
      for _, term in ipairs(all) do
        local highlight = term == p.selected and "TerminalPanelTabSelected" or "TerminalPanelTab"
        tabs[#tabs + 1] = ("%%#%s#%%%d@v:lua.NvimTerminalPanelClick@ %s %%T")
          :format(highlight, term.id, label(term):gsub("%%", "%%%%"))
      end
      tabs[#tabs + 1] = "%#TerminalPanelTab#%0@v:lua.NvimTerminalPanelClick@ + %T%*"
      vim.wo[p.window].winbar = table.concat(tabs)
    end
  end
end

function M.create(options)
  local terms = require("toggleterm.terminal")
  options = vim.tbl_extend("force", { direction = "horizontal", close_on_exit = false }, options or {})
  local occupied = {}
  for _, term in ipairs(M.all()) do occupied[term.id] = true end
  -- Never recycle an ID while an old job's exit callbacks may still be queued.
  local id = math.max(options.count or next_id, next_id)
  while occupied[id] do id = id + 1 end
  next_id = id + 1
  options.count = id
  local on_exit = options.on_exit
  options.on_exit = function(term, job, code, ...)
    term.panel_exit_code = code
    if on_exit then on_exit(term, job, code, ...) end
    vim.schedule(M.refresh)
  end
  local term = terms.Terminal:new(options)
  term:spawn()
  vim.bo[term.bufnr].filetype = "toggleterm"
  vim.bo[term.bufnr].buflisted = false
  vim.b[term.bufnr].toggle_number = term.id
  entries[#entries + 1] = term
  return term
end

function M.show(term, options)
  options = options or {}
  if not valid(term) then return end
  if not vim.tbl_contains(entries, term) then entries[#entries + 1] = term end
  local tab = options.tab or api.nvim_get_current_tabpage()
  if not api.nvim_tabpage_is_valid(tab) then return end
  local p = panel(tab)
  if tab ~= api.nvim_get_current_tabpage() then
    -- A queued build/run transition must not pull the user into another tab.
    if visible(p) then
      if p.selected.window == p.window then p.selected.window = nil end
      api.nvim_win_set_buf(p.window, term.bufnr)
      term.window = p.window
    else
      p.window = nil
    end
    p.selected = term
    M.refresh()
    return
  end
  local origin = api.nvim_get_current_win()
  if origin ~= p.window and vim.bo[api.nvim_win_get_buf(origin)].buftype ~= "terminal" then
    p.editor = origin
  end
  local reuse = visible(p)
  if p.selected and p.selected.window == p.window then p.selected.window = nil end
  if not reuse then
    p.window = api.nvim_open_win(term.bufnr, false, {
      split = "below", win = -1, height = math.max(1, math.min(15, vim.o.lines - 4)),
    })
  else
    api.nvim_win_set_buf(p.window, term.bufnr)
  end
  p.selected = term
  term.window = p.window
  vim.wo[p.window].winfixheight = true
  api.nvim_set_option_value("number", false, { scope = "local", win = p.window })
  api.nvim_set_option_value("relativenumber", false, { scope = "local", win = p.window })
  if options.focus == false then
    if p.editor and api.nvim_win_is_valid(p.editor) then api.nvim_set_current_win(p.editor) end
    vim.cmd.stopinsert()
  else
    api.nvim_set_current_win(p.window)
    if term.panel_exit_code == nil then
      vim.cmd.startinsert()
    else
      vim.cmd.stopinsert()
    end
  end
  M.refresh()
end

function M.new_shell()
  shell_count = shell_count + 1
  local term = M.create({ display_name = "Shell " .. shell_count })
  M.show(term)
  return term
end

function M.hide()
  local p = panel()
  if not visible(p) then return end
  if p.selected.window == p.window then p.selected.window = nil end
  close_window(p)
  p.window = nil
  if p.editor and api.nvim_win_is_valid(p.editor) then api.nvim_set_current_win(p.editor) end
  vim.cmd.stopinsert()
end

function M.open_file(with_position)
  local name = vim.fn.expand("<cfile>")
  local path = name ~= "" and vim.fn.findfile(name:gsub("\\ ", " "), vim.o.path, vim.v.count1) or ""
  if path == "" then
    vim.notify("File not found: " .. name, vim.log.levels.WARN)
    return
  end
  path = vim.fn.fnamemodify(path, ":p")

  local row, column
  if with_position then
    local text, cursor = api.nvim_get_current_line(), api.nvim_win_get_cursor(0)[2] + 1
    local start = 1
    while true do
      local first, last = text:find(name, start, true)
      if not first then break end
      if last >= cursor then
        local suffix = text:sub(last + 1)
        row, column = suffix:match("^%s*%(%s*(%d+)%s*,%s*(%d+)")
        if not row then row, column = suffix:match("^%s*:%s*(%d+)%s*:%s*(%d+)") end
        row = row or suffix:match("^%s*%D+%s*(%d+)") or suffix:match("^%s+(%d+)")
        break
      end
      start = last + 1
    end
  end

  local p = panel()
  local function editor(win)
    return win and api.nvim_win_is_valid(win) and win ~= p.window
      and api.nvim_win_get_config(win).relative == ""
      and vim.bo[api.nvim_win_get_buf(win)].buftype == ""
  end
  local destination = editor(p.editor) and p.editor or nil
  if not destination then
    for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
      if editor(win) then destination = win; break end
    end
  end
  if destination then api.nvim_set_current_win(destination) else vim.cmd("aboveleft new") end
  p.editor = api.nvim_get_current_win()
  vim.cmd.edit(vim.fn.fnameescape(path))
  -- Terminal window settings can be inherited by a split or saved in a session.
  api.nvim_set_option_value("number", vim.go.number, { scope = "local", win = p.editor })
  if not destination then
    api.nvim_set_option_value("relativenumber", vim.go.relativenumber, { scope = "local", win = p.editor })
  end
  if row then
    local line = math.max(1, math.min(tonumber(row), api.nvim_buf_line_count(0)))
    local width = #api.nvim_buf_get_lines(0, line - 1, line, false)[1]
    api.nvim_win_set_cursor(0, { line, math.max(0, math.min((tonumber(column) or 1) - 1, width)) })
    vim.cmd("normal! zv")
  end
end

function M.toggle()
  local p = panel()
  if visible(p) then M.hide(); return end
  local all = M.all()
  local selected = valid(p.selected) and p.selected or all[1]
  if selected then M.show(selected, { focus = selected.panel_kind ~= "output" }) else M.new_shell() end
end

function M.select()
  local all = M.all()
  if #all == 0 then M.new_shell(); return end
  vim.ui.select(all, {
    prompt = "Terminals",
    format_item = function(term)
      return label(term) .. (term.panel_kind == "output" and term.cmd and (" · " .. term.cmd) or "")
    end,
  }, function(term)
    if term then M.show(term) end
  end)
end

function M.cycle(step)
  local all = M.all()
  if #all == 0 then M.new_shell(); return end
  local index = 1
  for i, term in ipairs(all) do if term == panel().selected then index = i; break end end
  M.show(all[(index - 1 + step) % #all + 1])
end

function M.rename()
  local term = panel().selected
  if not valid(term) then return end
  vim.ui.input({ prompt = "Terminal name: ", default = term.display_name }, function(name)
    if name and vim.trim(name) ~= "" then term.display_name = vim.trim(name); M.refresh() end
  end)
end

function M.dispose(term)
  if not term then return end
  for _, p in pairs(panels) do
    if p.selected == term then
      -- Detach its window before shutdown so ToggleTerm cannot close a source
      -- window or another terminal that has since occupied the panel.
      if visible(p) then close_window(p) end
      p.window, p.selected = nil, nil
    end
  end
  term.window = nil
  entries = vim.tbl_filter(function(entry) return entry ~= term end, entries)
  local registered = require("toggleterm.terminal").get(term.id, true)
  if registered and registered ~= term then
    -- A terminal opened outside this panel may have reused a finished job's ID.
    if valid(term) then api.nvim_buf_delete(term.bufnr, { force = true }) end
  else
    term:shutdown()
  end
  M.refresh()
end

function M.close()
  local term = panel().selected
  if not valid(term) then return end
  local function close()
    M.dispose(term)
    local all = M.all()
    if #all > 0 then M.show(all[1]) end
  end
  if term.panel_exit_code ~= nil then close(); return end
  vim.ui.select({ "Cancel", "Close" }, {
    prompt = "Close " .. label(term) .. " and stop its process?",
  }, function(choice) if choice == "Close" then close() end end)
end

function M.setup()
  header_highlights()
  api.nvim_create_autocmd("ColorScheme", {
    group = api.nvim_create_augroup("TerminalPanelHighlights", { clear = true }),
    callback = function() header_highlights(); M.refresh() end,
  })
  _G.NvimTerminalPanelClick = function(id)
    if id == 0 then M.new_shell(); return end
    for _, term in ipairs(M.all()) do if term.id == id then M.show(term); return end end
  end
  api.nvim_create_autocmd({ "BufEnter", "TermClose", "BufDelete" }, {
    group = api.nvim_create_augroup("TerminalPanel", { clear = true }),
    callback = function() vim.schedule(M.refresh) end,
  })
end

return M
