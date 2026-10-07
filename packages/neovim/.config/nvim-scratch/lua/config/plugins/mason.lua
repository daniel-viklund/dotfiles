vim.pack.add({
  "https://github.com/neovim/nvim-lspconfig",
  "https://github.com/mason-org/mason.nvim.git",
  "https://github.com/mason-org/mason-lspconfig.nvim",
})

require("mason").setup()

local opts = {
  -- Use LSPConfig names here.
  -- mason-lspconfig maps these to their corresponding Mason packages.
  ensure_installed = {
    -- Lua / Neovim
    "lua_ls",

    -- TypeScript / JavaScript / React
    "vtsls",
    "eslint",

    -- Web
    "html",
    "cssls",
    "jsonls",
    "tailwindcss",

    -- Config / markup
    "yamlls",
    "marksman",

    -- Shell
    "bashls",

    -- Rust
    "rust_analyzer",

    -- Go
    "gopls",

    -- Python
    "basedpyright",

    -- C / C++
    "clangd",

    -- Docker
    "dockerls",
  },

  -- Automatically enable servers installed through Mason.
  automatic_enable = true,
}

require("mason-lspconfig").setup(opts)

return opts
