vim.pack.add({
  "https://github.com/akinsho/toggleterm.nvim.git",
})

require("toggleterm").setup({
  direction = "horizontal",
  size = 15,
  shade_terminals = false,
  start_in_insert = true,
  persist_size = false,
  persist_mode = true,
  close_on_exit = false,
})

local terminals = require("config.terminals")
terminals.setup()
require("config.runner").setup()

vim.keymap.set("n", [[<C-\>]], terminals.toggle, { desc = "Toggle terminal panel" })
vim.keymap.set("n", "]t", function() terminals.cycle(1) end, { desc = "Next terminal" })
vim.keymap.set("n", "[t", function() terminals.cycle(-1) end, { desc = "Previous terminal" })

-- Shell mappings stay buffer-local so unrelated TUIs keep their own keys.
vim.api.nvim_create_autocmd("TermOpen", {
  group = vim.api.nvim_create_augroup("TerminalPanelKeys", { clear = true }),
  pattern = { "term://*#toggleterm#*", "term://*::toggleterm::*" },
  callback = function()
    local opts = { buffer = 0 }
    vim.keymap.set("t", [[<C-\>]], terminals.toggle, { buffer = 0, desc = "Toggle terminal panel" })
    vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)
    vim.keymap.set("n", "gf", function() terminals.open_file(false) end,
      { buffer = 0, desc = "Open file under cursor in editor" })
    vim.keymap.set("n", "gF", function() terminals.open_file(true) end,
      { buffer = 0, desc = "Open file at line under cursor in editor" })
    vim.keymap.set({ "n", "t" }, "<C-h>", function() terminals.cycle(-1) end,
      { buffer = 0, desc = "Previous terminal" })
    vim.keymap.set("t", "<C-j>", [[<Cmd>TmuxNavigateDown<CR>]], opts)
    vim.keymap.set("t", "<C-k>", [[<Cmd>TmuxNavigateUp<CR>]], opts)
    vim.keymap.set({ "n", "t" }, "<C-l>", function() terminals.cycle(1) end,
      { buffer = 0, desc = "Next terminal" })
  end,
})
