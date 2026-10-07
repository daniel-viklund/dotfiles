vim.pack.add({
  "https://github.com/rmagatti/auto-session",
})

-- Restore editor windows and hidden file buffers, without restarting terminals.
vim.opt.sessionoptions = {
  "blank", "buffers", "curdir", "folds", "help", "tabpages",
  "winsize", "winpos", "localoptions",
}

require("auto-session").setup({
  auto_save = true,
  auto_restore = true,
  auto_create = true,
  suppressed_dirs = { "~/", "/" },
  bypass_save_filetypes = { "startscreen" },
  -- Saving a session should not close terminals or other plugin windows.
  close_unsupported_windows = false,
  -- :mksession equalizes splits when it omits terminal windows. Keep editor
  -- dimensions separately so those splits retain their sizing on restore.
  save_extra_data = function()
    local tabs = {}
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
      local windows = {}
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].buftype == "" and vim.api.nvim_win_get_config(win).relative == "" then
          windows[#windows + 1] = {
            name = vim.api.nvim_buf_get_name(buf),
            width = vim.api.nvim_win_get_width(win),
            height = vim.api.nvim_win_get_height(win),
          }
        end
      end
      tabs[#tabs + 1] = windows
    end
    return vim.json.encode({ tabs = tabs, columns = vim.o.columns, lines = vim.o.lines })
  end,
  restore_extra_data = function(_, data)
    local saved = vim.json.decode(data)
    for index, tab in ipairs(vim.api.nvim_list_tabpages()) do
      for position, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        local dimensions = (saved.tabs[index] or {})[position]
        if dimensions and vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)) == dimensions.name then
          vim.api.nvim_win_set_width(win, math.max(1, math.floor(dimensions.width * vim.o.columns / saved.columns)))
          vim.api.nvim_win_set_height(win, math.max(1, math.floor(dimensions.height * vim.o.lines / saved.lines)))
        end
      end
    end
  end,
  session_lens = {
    picker = "telescope",
    -- Telescope is configured later in the alphabetical plugin load order.
    load_on_setup = false,
  },
})

vim.keymap.set("n", "<leader>ss", "<cmd>AutoSession search<CR>", {
  desc = "Search saved sessions",
})
vim.keymap.set("n", "<leader>ws", "<cmd>AutoSession save<CR>", {
  desc = "Save session",
})
vim.keymap.set("n", "<leader>wr", "<cmd>AutoSession restore<CR>", {
  desc = "Restore session for current directory",
})
