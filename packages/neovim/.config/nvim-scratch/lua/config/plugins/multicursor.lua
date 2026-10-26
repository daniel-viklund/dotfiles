-- Neovim 0.13 provides native multicursors; retain the plugin for stable 0.12.
if vim.fn.has("nvim-0.13") == 1 then
  local ns = vim.api.nvim_create_namespace("nvim.multicursor")

  vim.keymap.set("x", "I", "QI", { desc = "Multicursor: Insert on selected lines" })
  vim.keymap.set("x", "A", "QA", { desc = "Multicursor: Append on selected lines" })
  vim.keymap.set("n", "<leader>mj", "1Qj1Q", { desc = "Multicursor: Add cursor below" })
  vim.keymap.set("n", "<leader>mk", "1Qk1Q", { desc = "Multicursor: Add cursor above" })
  vim.keymap.set("n", "<leader>mn", "1Q*1Q", { desc = "Multicursor: Add next matching word" })
  vim.keymap.set("n", "<leader>mN", "1Q#1Q", { desc = "Multicursor: Add previous matching word" })
  vim.keymap.set("n", "<leader>ma", "zq*", { desc = "Multicursor: Add all matching words" })
  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
    vim.cmd.nohlsearch()
  end, { desc = "Clear extra cursors and search highlight" })

  local function highlights()
    vim.api.nvim_set_hl(0, "MCursor", { fg = "#000000", bg = "#fbcb97" })
  end
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("ConfigMulticursorHighlights", { clear = true }),
    callback = highlights,
  })
  highlights()
  return
end

vim.pack.add({
  { src = "https://github.com/jake-stewart/multicursor.nvim", version = "1.0" },
})

local mc = require("multicursor-nvim")
mc.setup({
  -- Toggling 'hlsearch' off stops Noice's search-counter cleanup timer.
  -- Keep it enabled so :nohlsearch on Escape clears the counter as well.
  hlsearch = true,
})

-- Turn each selected line into a visible cursor before inserting/appending.
vim.keymap.set("x", "I", mc.insertVisual, { desc = "Multicursor: Insert on selected lines" })
vim.keymap.set("x", "A", mc.appendVisual, { desc = "Multicursor: Append on selected lines" })

vim.keymap.set({ "n", "x" }, "<leader>mj", function()
  mc.lineAddCursor(1)
end, { desc = "Multicursor: Add cursor below" })

vim.keymap.set({ "n", "x" }, "<leader>mk", function()
  mc.lineAddCursor(-1)
end, { desc = "Multicursor: Add cursor above" })

vim.keymap.set({ "n", "x" }, "<leader>mn", function()
  mc.matchAddCursor(1)
end, { desc = "Multicursor: Add next match" })

vim.keymap.set({ "n", "x" }, "<leader>mN", function()
  mc.matchAddCursor(-1)
end, { desc = "Multicursor: Add previous match" })

vim.keymap.set({ "n", "x" }, "<leader>ma", mc.matchAllAddCursors, {
  desc = "Multicursor: Add all matches",
})

-- Only override Escape while extra cursors exist; keep search clearing too.
mc.addKeymapLayer(function(set)
  set("n", "<Esc>", function()
    mc.clearCursors()
    vim.cmd.nohlsearch()
  end, { desc = "Clear extra cursors and search highlight" })
end)

local function highlights()
  vim.api.nvim_set_hl(0, "MultiCursorCursor", { fg = "#191724", bg = "#f6c177" })
  vim.api.nvim_set_hl(0, "MultiCursorDisabledCursor", { fg = "#191724", bg = "#908caa" })
  vim.api.nvim_set_hl(0, "MultiCursorVisual", { link = "Visual" })
  vim.api.nvim_set_hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("ConfigMulticursorHighlights", { clear = true }),
  callback = highlights,
})
highlights()
