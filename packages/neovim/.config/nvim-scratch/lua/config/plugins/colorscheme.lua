vim.pack.add({
  { src = "https://github.com/morhetz/gruvbox.git", name = "gruvbox" },
})

vim.opt.background = "dark"
vim.g.gruvbox_contrast_dark = "medium"
-- Git signs inherit Gruvbox's sign highlights, including their background.
vim.g.gruvbox_sign_column = "dark0"
-- Preserve syntax foregrounds when selecting text instead of reversing them.
vim.g.gruvbox_invert_selection = 0
vim.cmd.colorscheme("gruvbox")

-- Blend gutters and popup surfaces into the editor background.
local function match_popup_backgrounds()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  vim.api.nvim_set_hl(0, "Visual", { bg = "#504945", ctermbg = 239, reverse = false })
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

  -- The original Vim theme does not style Neovim's WinSeparator. Status-line
  -- fill also needs explicit colors to avoid a reversed bright terminal divider.
  for _, name in ipairs({ "WinSeparator", "VertSplit", "StatusLine", "StatusLineNC" }) do
    vim.api.nvim_set_hl(0, name, {
      fg = "#665c54", bg = normal.bg,
      ctermfg = 241, ctermbg = normal.ctermbg,
      reverse = false,
    })
  end
end

match_popup_backgrounds()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("EditorPopupBackgrounds", { clear = true }),
  callback = match_popup_backgrounds,
})
