vim.pack.add({
  "https://github.com/nvim-treesitter/nvim-treesitter",
})

local treesitter = require("nvim-treesitter")

treesitter.setup()

-- tree-sitter-cli otherwise defaults to MSVC on Windows.
if vim.fn.has("win32") == 1 and not vim.env.CC and vim.fn.executable("gcc") == 1 then
  vim.env.CC = "gcc"
end

local installation = treesitter.install({
  -- Lua / Neovim
  "lua",

  -- TypeScript / JavaScript / React (also used by ESLint)
  "javascript",
  "typescript",
  "tsx",

  -- Web (Tailwind uses the parsers for its host languages)
  "html",
  "css",
  "json",

  -- Config / markup
  "yaml",
  "markdown",
  "markdown_inline",

  -- Shell
  "bash",

  -- Rust
  "rust",

  -- Go
  "go",
  "gomod",
  "gosum",
  "gowork",

  -- Python
  "python",

  -- C / C++
  "c",
  "cpp",

  -- Docker
  "dockerfile",
})

vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    local ok = pcall(vim.treesitter.start, args.buf)

    if not ok then
      return
    end

    -- Treesitter folding
    vim.wo.foldmethod = "expr"
    vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    vim.wo.foldlevel = 99
  end,
})

return installation
