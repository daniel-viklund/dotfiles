vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.keymap.set("i", "jk", "<Esc>")
-- Terminal mappings live in config.plugins.toggleterm so TUIs receive their own keys.
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", {
  desc = "Clear search highlight",
})
vim.keymap.set("n", "<C-h>", "<C-w>h", {
  desc = "Move to left window",
})
vim.keymap.set("n", "<C-j>", "<C-w>j", {
  desc = "Move to lower window",
})
vim.keymap.set("n", "<C-k>", "<C-w>k", {
  desc = "Move to upper window",
})
vim.keymap.set("n", "<C-l>", "<C-w>l", {
  desc = "Move to right window",
})
