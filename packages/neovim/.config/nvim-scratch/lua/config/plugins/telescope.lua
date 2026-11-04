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

local function search_with_hidden_toggle(picker, title, opts)
  local picker_opts = vim.deepcopy(opts)
  picker_opts.prompt_title = title .. (opts.hidden and " (hidden on)" or " (hidden off)")
  picker_opts.file_ignore_patterns = { "^%.git/", "/%.git/" }
  if picker ~= "find_files" then
    -- Exclude Git metadata from the scan, including when hidden files are on.
    picker_opts.additional_args = { "--glob", "!**/.git/**" }
  end
  picker_opts.attach_mappings = function(_, map)
    map({ "i", "n" }, "<C-h>", function(prompt_bufnr)
      local state = require("telescope.actions.state")
      local next_opts = vim.deepcopy(opts)
      next_opts.hidden = not opts.hidden
      next_opts.default_text = state.get_current_line()
      next_opts.cwd = state.get_current_picker(prompt_bufnr).cwd
      require("telescope.actions").close(prompt_bufnr)
      search_with_hidden_toggle(picker, title, next_opts)
    end, { desc = "Toggle hidden files" })
    return true
  end
  builtin[picker](picker_opts)
end

vim.keymap.set('n', '<leader>sf', function()
  search_with_hidden_toggle("find_files", "Find Files", { hidden = false })
end, { desc = 'Telescope find files' })
vim.keymap.set('n', '<leader>sg', function()
  search_with_hidden_toggle("live_grep", "Live Grep", { hidden = false })
end, { desc = 'Telescope live grep' })
vim.keymap.set('n', '<leader>sw', function()
  search_with_hidden_toggle("grep_string", "Grep Word", {
    hidden = false,
    -- Keep the original word when the picker is reopened by the toggle.
    search = vim.fn.expand("<cword>"),
  })
end, { desc = 'Search word under cursor' })
vim.keymap.set('n', '<leader>sb', builtin.buffers, { desc = 'Search open buffers' })
vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = 'Search help' })
vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = 'Resume last search' })
vim.keymap.set('n', '<leader>sd', function()
  builtin.diagnostics({ bufnr = 0, sort_by = 'severity', line_width = 'full' })
end, { desc = 'Search diagnostics in current buffer' })
vim.keymap.set('n', '<leader>sD', function()
  builtin.diagnostics({ sort_by = 'severity', line_width = 'full' })
end, { desc = 'Search diagnostics in all buffers' })
