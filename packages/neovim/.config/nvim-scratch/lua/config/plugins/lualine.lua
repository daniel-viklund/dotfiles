vim.pack.add({
  "https://github.com/SmiteshP/nvim-navic",
  "https://github.com/nvim-lualine/lualine.nvim",
})

local navic = require("nvim-navic")

local function display_filename(name)
  if vim.bo.filetype == "oil" then
    local directory = require("oil").get_current_dir()
    if directory then
      local path = vim.fn.fnamemodify(directory, ":~")
      if path ~= "/" and not path:match("^%a:[/\\]$") then
        path = path:gsub("[/\\]+$", "")
      end
      return "Directory · " .. path
    end
  end
  return name
end

require("lualine").setup({
  options = {
    theme = "auto",
    globalstatus = false,

    disabled_filetypes = {
      winbar = {
        "noice",
        "toggleterm",
        "startscreen",
      },
    },
  },

  sections = {},
  inactive_sections = {},

  winbar = {
    lualine_x = { "branch", "diff", "diagnostics" },
    lualine_z = { "mode" },
    lualine_c = {
      {
        "filename",
        path = 1,
        fmt = display_filename,
      },

      {
        function()
          if navic.is_available() then
            local location = navic.get_location()

            if location ~= "" then
              return "> " .. location
            end
          end

          return " "
        end,
      },
    },
  },

  inactive_winbar = {
    lualine_c = {
      {
        "filename",
        path = 1,
        fmt = display_filename,
      },
    },
  },
})

-- Keep status information in the winbar without an empty bar at the bottom.
vim.opt.laststatus = 0

-- Other splits still have status lines; render them as plain dividers.
local function set_divider_highlight()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  local separator = vim.api.nvim_get_hl(0, { name = "WinSeparator", link = false })
  vim.api.nvim_set_hl(0, "SplitDivider", {
    fg = separator.fg or normal.fg,
    bg = normal.bg or "NONE",
  })
end

set_divider_highlight()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("SplitDividerHighlight", { clear = true }),
  callback = set_divider_highlight,
})

vim.opt.statusline = "%#SplitDivider#%="
vim.opt.fillchars:append({ stl = "─", stlnc = "─" })
