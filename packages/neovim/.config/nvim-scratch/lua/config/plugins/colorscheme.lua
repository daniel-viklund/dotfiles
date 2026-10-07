vim.pack.add({
  { src = "https://github.com/rose-pine/neovim", name = "rose-pine" },
})

require("rose-pine").setup()
vim.cmd("colorscheme rose-pine")

-- Keep hover, signature help, and completion surfaces on the editor background.
local function match_popup_backgrounds()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  for _, name in ipairs({
    "NormalFloat", "FloatBorder", "FloatTitle", "Pmenu",
    "BlinkCmpMenu", "BlinkCmpMenuBorder",
    "BlinkCmpDoc", "BlinkCmpDocBorder", "BlinkCmpDocSeparator",
    "BlinkCmpSignatureHelp", "BlinkCmpSignatureHelpBorder",
  }) do
    local highlight = vim.api.nvim_get_hl(0, { name = name, link = false })
    highlight.bg = normal.bg or "NONE"
    vim.api.nvim_set_hl(0, name, highlight)
  end
end

match_popup_backgrounds()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("EditorPopupBackgrounds", { clear = true }),
  callback = match_popup_backgrounds,
})
