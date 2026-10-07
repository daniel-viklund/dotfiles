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

-- Terminal mode mappings
vim.api.nvim_create_autocmd("TermOpen", {
  pattern = { "term://*#toggleterm#*", "term://*::toggleterm::*" },
  callback = function()
    local opts = { buffer = 0 }

    vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)

    vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
    vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
    vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
    vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
  end,
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
vim.keymap.set("n", "<leader>tt", function()
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
    for _, term in ipairs(hidden_terminals[tab] or {}) do
      -- Exited shells or replaced project jobs must not be launched again.
      if term.bufnr and api.nvim_buf_is_valid(term.bufnr) then
        term:open()
      end
    end
    hidden_terminals[tab] = nil
    if api.nvim_win_is_valid(window) then api.nvim_set_current_win(window) end
    vim.cmd.stopinsert()
  end
end, { desc = "Toggle visible terminals" })

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
