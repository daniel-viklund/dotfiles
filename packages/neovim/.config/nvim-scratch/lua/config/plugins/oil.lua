vim.pack.add({
  "https://github.com/stevearc/oil.nvim",
})

require("oil").setup({
  keymaps = {
    ["q"] = "actions.close",
    ["<C-o>"] = {
      function()
        local dir = require("oil").get_current_dir()
        if dir then
          vim.ui.open(dir)
        end
      end,
      mode = "n",
      desc = "Open current directory in system file manager",
    },
  },
})

vim.keymap.set("n", "-", "<cmd>Oil<CR>", {
  desc = "Open parent directory",
})
