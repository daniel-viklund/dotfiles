vim.pack.add({
  "https://github.com/kdheepak/lazygit.nvim",
})

vim.keymap.set("n", "<leader>gg", "<cmd>LazyGitCurrentFile<CR>", {
  desc = "Open LazyGit for current file's repo",
  silent = true,
})

vim.keymap.set("n", "<leader>gG", "<cmd>LazyGit<CR>", {
  desc = "Open LazyGit for working-directory repo",
  silent = true,
})
