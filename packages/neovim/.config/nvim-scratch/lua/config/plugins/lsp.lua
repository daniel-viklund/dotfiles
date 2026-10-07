vim.pack.add({
    "https://github.com/neovim/nvim-lspconfig",
    "https://github.com/SmiteshP/nvim-navic",
})

-- Diagnostics
vim.diagnostic.config({
    severity_sort = true,

    float = {
        border = "rounded",
        source = true,
    },

    underline = true,
    signs = true,

    virtual_text = {
        spacing = 2,
        source = "if_many",
    },
})

-- Server-specific configuration
vim.lsp.config("lua_ls", {
    settings = {
        Lua = {
            runtime = {
                version = "LuaJIT",
            },

            diagnostics = {
                globals = {
                    "vim",
                },
            },

            workspace = {
                library = {
                    vim.env.VIMRUNTIME,
                },
            },

            telemetry = {
                enable = false,
            },
        },
    },
})

-- LSP keymaps
-- Remove Neovim's global defaults so they do not extend our `gr` mapping.
for _, keys in ipairs({ "gra", "gri", "grn", "grr", "grt", "grx" }) do
    pcall(vim.keymap.del, "n", keys)
end
pcall(vim.keymap.del, "x", "gra")

local lsp_group = vim.api.nvim_create_augroup("lsp-attach", {
    clear = true,
})

vim.api.nvim_create_autocmd("LspAttach", {
    group = lsp_group,

    callback = function(event)
        local client = vim.lsp.get_client_by_id(event.data.client_id)

        local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, {
                buffer = event.buf,
                desc = "LSP: " .. desc,
            })
        end

        -- Navigation
        map("gd", vim.lsp.buf.definition, "Goto definition")
        map("gD", vim.lsp.buf.declaration, "Goto declaration")
        map("gi", vim.lsp.buf.implementation, "Goto implementation")
        map("gr", function()
            require("telescope.builtin").lsp_references()
        end, "Goto references")

        -- Documentation
        map("K", vim.lsp.buf.hover, "Hover documentation")

        -- Refactoring / actions
        map("<leader>lr", vim.lsp.buf.rename, "Rename")
        map("<leader>lc", vim.lsp.buf.code_action, "Code action")
        map("<leader>lf", vim.lsp.buf.format, "Format")

        -- Symbols
        map("<leader>ld", vim.lsp.buf.document_symbol, "Document symbols")
        map("<leader>lw", vim.lsp.buf.workspace_symbol, "Workspace symbols")

        -- Diagnostics
        map("[d", function()
            vim.diagnostic.jump({
                count = -1,
                float = true,
            })
        end, "Previous diagnostic")

        map("]d", function()
            vim.diagnostic.jump({
                count = 1,
                float = true,
            })
        end, "Next diagnostic")

        -- Navic breadcrumbs
        if
            client
            and client:supports_method("textDocument/documentSymbol")
        then
            require("nvim-navic").attach(client, event.buf)
        end
    end,
})
