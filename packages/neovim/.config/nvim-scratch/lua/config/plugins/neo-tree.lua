vim.pack.add({
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/MunifTanjim/nui.nvim.git",
  "https://github.com/nvim-tree/nvim-web-devicons",
  { src = "https://github.com/nvim-neo-tree/neo-tree.nvim", version = "v3.x" },
})

require("neo-tree").setup({
  window = {
    -- Replace the current editor window; opening a file replaces the tree.
    position = "current",
    mappings = {
      ["<CR>"] = "open",
      ["q"] = "close_window",
    },
  },
  filesystem = {
    filtered_items = {
      visible = true, -- Show hidden and gitignored files by default.
    },
    -- Keep Oil as the directory handler while trying Neo-tree alongside it.
    hijack_netrw_behavior = "disabled",
    bind_to_cwd = false,
  },
})

local function match_editor_background()
  vim.api.nvim_set_hl(0, "NeoTreeNormal", { link = "Normal" })
  vim.api.nvim_set_hl(0, "NeoTreeNormalNC", { link = "NormalNC" })
  vim.api.nvim_set_hl(0, "NeoTreeEndOfBuffer", { link = "EndOfBuffer" })
end

match_editor_background()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("NeoTreeEditorBackground", { clear = true }),
  callback = match_editor_background,
})

vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle current reveal<CR>", {
  desc = "Toggle Neo-tree in current window",
})
