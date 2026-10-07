-- A decorative start screen, without another dashboard plugin.
local group = vim.api.nvim_create_augroup("MinimalStart", { clear = true })
local stdin = false
local ready = false

vim.api.nvim_create_autocmd("StdinReadPre", {
  group = group,
  callback = function()
    stdin = true
  end,
})

local function show_if_empty()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].modified
    or vim.api.nvim_buf_get_name(buf) ~= "" or vim.bo[buf].buftype ~= ""
    or vim.api.nvim_buf_line_count(buf) ~= 1 or vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] ~= "" then
    return
  end

  -- Hidden files and unnamed drafts still count as open file buffers.
  for _, other in ipairs(vim.api.nvim_list_bufs()) do
    if other ~= buf and vim.bo[other].buflisted and vim.bo[other].buftype == "" then
      return
    end
  end
  if vim.api.nvim_win_get_config(0).relative ~= "" then
    return
  end

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_name(buf, "Start")
  vim.bo[buf].filetype = "startscreen"

  local win = vim.api.nvim_get_current_win()
  local saved = {}
  for option, value in pairs({
    number = false, relativenumber = false, signcolumn = "no",
    cursorline = false, cursorcolumn = false, wrap = false,
    list = false, spell = false, foldcolumn = "0", colorcolumn = "",
  }) do
    saved[option] = vim.wo[win][option]
    vim.wo[win][option] = value
  end

  local artwork = {
    [[███╗   ██╗ ███████╗ ██████╗  ██╗   ██╗ ██╗ ███╗   ███╗]],
    [[████╗  ██║ ██╔════╝██╔═══██╗ ██║   ██║ ██║ ████╗ ████║]],
    [[██╔██╗ ██║ █████╗  ██║   ██║ ██║   ██║ ██║ ██╔████╔██║]],
    [[██║╚██╗██║ ██╔══╝  ██║   ██║ ╚██╗ ██╔╝ ██║ ██║╚██╔╝██║]],
    [[██║ ╚████║ ███████╗╚██████╔╝  ╚████╔╝  ██║ ██║ ╚═╝ ██║]],
    [[╚═╝  ╚═══╝ ╚══════╝ ╚═════╝    ╚═══╝   ╚═╝ ╚═╝     ╚═╝]],
  }
  local function render()
    if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= buf then
      return
    end
    local width = vim.api.nvim_win_get_width(win)
    local art = width >= vim.fn.strdisplaywidth(artwork[1]) and artwork or { "N E O V I M" }
    local lines = {}
    for _ = 1, math.max(0, math.floor((vim.api.nvim_win_get_height(win) - #art) / 2)) do
      lines[#lines + 1] = ""
    end
    for _, line in ipairs(art) do
      lines[#lines + 1] = string.rep(" ", math.max(0, math.floor((width - vim.fn.strdisplaywidth(line)) / 2))) .. line
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modified = false
    vim.bo[buf].modifiable = false
    vim.wo[win].winhighlight = "Normal:Normal,EndOfBuffer:Normal"
  end
  saved.winhighlight = vim.wo[win].winhighlight
  render()
  vim.keymap.set("n", "q", "<cmd>quit<CR>", { buffer = buf, silent = true, desc = "Quit" })
  local resize = vim.api.nvim_create_autocmd("VimResized", { group = group, callback = render })
  vim.api.nvim_create_autocmd("BufLeave", {
    group = group, buffer = buf, once = true,
    callback = function()
      vim.api.nvim_del_autocmd(resize)
      if vim.api.nvim_win_is_valid(win) then
        for option, value in pairs(saved) do
          vim.wo[win][option] = value
        end
      end
    end,
  })
end

vim.api.nvim_create_autocmd("VimEnter", {
  group = group,
  once = true,
  callback = function()
    ready = true
    if not stdin and vim.fn.argc() == 0 then
      show_if_empty()
    end
  end,
})

-- Oil and :bdelete may create an empty buffer. Wait for their transitions
-- to finish before checking whether the home screen should return.
vim.api.nvim_create_autocmd({ "BufEnter", "BufDelete", "BufWipeout" }, {
  group = group,
  callback = function()
    if ready and vim.v.exiting == vim.NIL then
      vim.schedule(function()
        if vim.v.exiting == vim.NIL then
          show_if_empty()
        end
      end)
    end
  end,
})
