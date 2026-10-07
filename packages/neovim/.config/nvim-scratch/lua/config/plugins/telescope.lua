vim.pack.add({
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/nvim-telescope/telescope.nvim",
  "https://github.com/nvim-telescope/telescope-ui-select.nvim",
})

local telescope = require("telescope")

local function match_editor_background()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  for _, pane in ipairs({ "", "Prompt", "Results", "Preview" }) do
    for _, part in ipairs({ "Normal", "Border", "Title" }) do
      local name = "Telescope" .. pane .. part
      local highlight = vim.api.nvim_get_hl(0, { name = name, link = false })
      highlight.bg = normal.bg or "NONE"
      vim.api.nvim_set_hl(0, name, highlight)
    end
  end
end

match_editor_background()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("TelescopeEditorBackground", { clear = true }),
  callback = match_editor_background,
})

telescope.setup({
  extensions = {
    ["ui-select"] = require("telescope.themes").get_dropdown({
      previewer = false,
    }),
  },
  defaults = {
    layout_strategy = "vertical",
    layout_config = {
      vertical = {
        mirror = false,
        preview_cutoff = 10,
        preview_height = function(picker, _, height)
          -- Split the content 70/30 after reserving the prompt and borders/gaps.
          local spacing = picker.window.border == false and 2 or 6
          return math.max(1, math.floor((height - spacing - 1) * 0.7))
        end,
      },
    },
  },
})

-- Use Telescope for code actions and other vim.ui.select prompts.
telescope.load_extension("ui-select")

local builtin = require("telescope.builtin")

vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = 'Telescope find files' })
vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = 'Telescope live grep' })
