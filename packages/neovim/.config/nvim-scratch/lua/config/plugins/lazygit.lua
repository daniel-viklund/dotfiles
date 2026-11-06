vim.pack.add({
  "https://github.com/kdheepak/lazygit.nvim",
})

vim.keymap.set("n", "<leader>gg", function()
  require("config.lazygit").open()
end, {
  desc = "Open LazyGit (resume last repo)",
  silent = true,
})
