vim.pack.add({
  "https://github.com/akinsho/toggleterm.nvim.git",
})

require("toggleterm").setup({
  direction = "horizontal",
  size = 15,
  shade_terminals = false,

  start_in_insert = true,
  persist_size = false, -- Reopen at 15 lines instead of remembering a compressed split.
  persist_mode = true,

  close_on_exit = true,

  float_opts = {
    border = "rounded",
  },
})

-- Numbered terminals
vim.keymap.set("n", "<leader>t1", "<cmd>1ToggleTerm<CR>", {
  desc = "Terminal 1",
})

vim.keymap.set("n", "<leader>t2", "<cmd>2ToggleTerm<CR>", {
  desc = "Terminal 2",
})

vim.keymap.set("n", "<leader>t3", "<cmd>3ToggleTerm<CR>", {
  desc = "Terminal 3",
})

-- The project runner reserves terminal 4 and any additional command outputs.
require("config.runner").setup()

-- Remember the visible set in each tab, including finished project output.
local hidden_terminals = {}
local function toggle_terminals()
  local api = vim.api
  local tab = api.nvim_get_current_tabpage()
  local candidates = require("toggleterm.terminal").get_all(true)
  for _, project in ipairs(require("config.runner").terminals()) do
    if not vim.tbl_contains(candidates, project) then
      candidates[#candidates + 1] = project
    end
  end
  local visible = {}
  for _, term in ipairs(candidates) do
    if term.window and api.nvim_win_is_valid(term.window)
      and api.nvim_win_get_tabpage(term.window) == tab
      and api.nvim_win_get_buf(term.window) == term.bufnr then
      visible[#visible + 1] = term
    end
  end
  if #visible > 0 then
    hidden_terminals[tab] = visible
    for _, term in ipairs(visible) do term:close() end
  else
    local window = api.nvim_get_current_win()
    local restored = false
    local interactive
    for _, term in ipairs(hidden_terminals[tab] or {}) do
      -- Exited shells or replaced project jobs must not be launched again.
      if term.bufnr and api.nvim_buf_is_valid(term.bufnr) then
        term:open()
        restored = true
        if not interactive and not require("config.runner").reserves(term.id)
          and term.job_id and vim.fn.jobwait({ term.job_id }, 0)[1] == -1 then
          interactive = term
        end
      end
    end
    hidden_terminals[tab] = nil
    if not restored then
      vim.cmd("1ToggleTerm")
      return
    end
    local target = interactive and interactive.window or window
    if api.nvim_win_is_valid(target) then
      api.nvim_set_current_win(target)
      -- Apply after ToggleTerm's scheduled restoration of each terminal's mode.
      vim.schedule(function()
        if api.nvim_get_current_win() == target then
          vim.cmd(interactive and "startinsert" or "stopinsert")
        end
      end)
    end
  end
end

vim.keymap.set("n", [[<C-\>]], toggle_terminals, { desc = "Toggle terminals" })

-- Terminal mode mappings stay local so other TUIs receive their own keys.
vim.api.nvim_create_autocmd("TermOpen", {
  pattern = { "term://*#toggleterm#*", "term://*::toggleterm::*" },
  callback = function()
    local opts = { buffer = 0 }

    vim.keymap.set("t", [[<C-\>]], toggle_terminals, {
      buffer = 0,
      desc = "Toggle terminals",
    })
    vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)

    vim.keymap.set("t", "<C-h>", [[<Cmd>TmuxNavigateLeft<CR>]], opts)
    vim.keymap.set("t", "<C-j>", [[<Cmd>TmuxNavigateDown<CR>]], opts)
    vim.keymap.set("t", "<C-k>", [[<Cmd>TmuxNavigateUp<CR>]], opts)
    vim.keymap.set("t", "<C-l>", [[<Cmd>TmuxNavigateRight<CR>]], opts)
  end,
})

-- Create a fresh terminal
vim.keymap.set("n", "<leader>tn", function()
  local terminals = require("toggleterm.terminal")
  local id = 1
  while require("config.runner").reserves(id) or terminals.get(id, true) do id = id + 1 end
  terminals.Terminal:new({ count = id }):toggle()
end, {
  desc = "New terminal",
})

-- Choose from existing terminals
vim.keymap.set("n", "<leader>ts", "<cmd>TermSelect<CR>", {
  desc = "Select terminal",
})
