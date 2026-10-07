vim.pack.add({
  "https://github.com/lewis6991/gitsigns.nvim",
})

local gitsigns = require("gitsigns")
gitsigns.setup({
  signcolumn = true,
  current_line_blame = false,
  on_attach = function(bufnr)
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
    end

    map("n", "]c", function()
      if vim.wo.diff then
        vim.cmd.normal({ "]c", bang = true })
      else
        gitsigns.nav_hunk("next")
      end
    end, "Next Git change")
    map("n", "[c", function()
      if vim.wo.diff then
        vim.cmd.normal({ "[c", bang = true })
      else
        gitsigns.nav_hunk("prev")
      end
    end, "Previous Git change")

    map("n", "<leader>gp", gitsigns.preview_hunk, "Preview Git hunk")
    map("n", "<leader>gs", gitsigns.stage_hunk, "Stage/unstage Git hunk")
    map("n", "<leader>gr", gitsigns.reset_hunk, "Reset Git hunk")
    map("x", "<leader>gs", function()
      gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end, "Stage/unstage selected lines")
    map("x", "<leader>gr", function()
      gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end, "Reset selected lines")
    map("n", "<leader>gb", function()
      gitsigns.blame_line({ full = true })
    end, "Git blame for line")
    map("n", "<leader>gB", gitsigns.toggle_current_line_blame, "Toggle inline Git blame")
    map("n", "<leader>gd", gitsigns.diffthis, "Diff file against index")
  end,
})
