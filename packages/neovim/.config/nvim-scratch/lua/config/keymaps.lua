vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.keymap.set("i", "jk", "<Esc>")
-- Terminal mappings live in config.plugins.toggleterm so TUIs receive their own keys.
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", {
  desc = "Clear search highlight",
})
vim.keymap.set("n", "<C-h>", "<cmd>TmuxNavigateLeft<CR>", {
  desc = "Move to left window or tmux pane",
})
vim.keymap.set("n", "<C-j>", "<cmd>TmuxNavigateDown<CR>", {
  desc = "Move to lower window or tmux pane",
})
vim.keymap.set("n", "<C-k>", "<cmd>TmuxNavigateUp<CR>", {
  desc = "Move to upper window or tmux pane",
})
vim.keymap.set("n", "<C-l>", "<cmd>TmuxNavigateRight<CR>", {
  desc = "Move to right window or tmux pane",
})
