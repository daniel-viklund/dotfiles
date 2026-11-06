vim.pack.add({
  { src = "https://github.com/projekt0n/github-nvim-theme", name = "github-theme" },
})

vim.opt.background = "dark"
require("github-theme").setup({})
vim.cmd('colorscheme github_dark_default')

-- Blend gutters and popup surfaces into the editor background.
local function match_popup_backgrounds()
  if not (vim.g.colors_name or ""):match("^github_") then return end
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  local spec = require("github-theme.spec").load(vim.g.colors_name)
  vim.api.nvim_set_hl(0, "Visual", { bg = spec.sel0, reverse = false })
  vim.api.nvim_set_hl(0, "VisualNOS", { link = "Visual" })
  for _, name in ipairs({
    "SignColumn", "FoldColumn",
    "NormalFloat", "FloatBorder", "FloatTitle", "Pmenu",
    "BlinkCmpMenu", "BlinkCmpMenuBorder",
    "BlinkCmpDoc", "BlinkCmpDocBorder", "BlinkCmpDocSeparator",
    "BlinkCmpSignatureHelp", "BlinkCmpSignatureHelpBorder",
  }) do
    local highlight = vim.api.nvim_get_hl(0, { name = name, link = false })
    highlight.bg = normal.bg or "NONE"
    vim.api.nvim_set_hl(0, name, highlight)
  end

  -- Keep separators subtle and status-line fill on the shared background.
  for _, name in ipairs({ "WinSeparator", "VertSplit", "StatusLine", "StatusLineNC" }) do
    vim.api.nvim_set_hl(0, name, {
      fg = spec.palette.border.muted, bg = normal.bg,
      reverse = false,
    })
  end
end

match_popup_backgrounds()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("EditorPopupBackgrounds", { clear = true }),
  callback = match_popup_backgrounds,
})
