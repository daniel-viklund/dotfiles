vim.pack.add({
  "https://github.com/kdheepak/lazygit.nvim",
})

vim.keymap.set("n", "<leader>gg", "<cmd>LazyGit<CR>", {
  desc = "Open LazyGit",
  silent = true,
})
