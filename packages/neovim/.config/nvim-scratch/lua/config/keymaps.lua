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

-- Carry the current file into a split, leaving this window's previous file behind.
local function move_to_split(command)
  local api = vim.api
  local window = api.nvim_get_current_win()
  local previous = vim.fn.bufnr("#")
  if vim.bo.buftype ~= "" or previous == api.nvim_get_current_buf()
    or not api.nvim_buf_is_valid(previous) or not vim.bo[previous].buflisted
    or vim.bo[previous].buftype ~= "" then
    vim.notify("No previous file in this window to leave behind", vim.log.levels.INFO)
    return
  end
  vim.cmd(command)
  api.nvim_win_set_buf(window, previous)
end

for key, split in pairs({
  h = { "leftabove vsplit", "left" },
  j = { "rightbelow split", "below" },
  k = { "leftabove split", "above" },
  l = { "rightbelow vsplit", "right" },
}) do
  vim.keymap.set("n", "<leader>w" .. key, function() move_to_split(split[1]) end, {
    desc = "Move file to split " .. split[2] .. " (leave previous file)",
  })
end
