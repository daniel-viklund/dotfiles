vim.pack.add({
    "https://github.com/neovim/nvim-lspconfig",
    "https://github.com/SmiteshP/nvim-navic",
})

-- Diagnostics
vim.diagnostic.config({
    severity_sort = true,
    update_in_insert = false,

    float = {
        border = "rounded",
        source = true,
    },

    underline = true,
    signs = true,

    virtual_text = { source = "if_many" },
    virtual_lines = false,
})

-- Server-specific configuration
vim.lsp.config("powershell_es", {
    on_init = function(client)
        -- PowerShell semantic tokens can become stale and override Tree-sitter.
        client.server_capabilities.semanticTokensProvider = nil
    end,
})

vim.lsp.config("vtsls", {
    settings = {
        typescript = {
            tsserver = {
                experimental = {
                    enableProjectDiagnostics = true,
                },
            },
        },
    },
})

-- rustaceanvim owns the Rust client and supplies Neotest discovery.
vim.g.rustaceanvim = {
    server = {
        settings = function(_, defaults)
            local settings = vim.deepcopy(defaults)
            -- Use the Windows target for Rust development inside WSL.
            if vim.fn.has("wsl") == 1 then
                settings["rust-analyzer"].cargo = {
                    target = "x86_64-pc-windows-gnu",
                    targetDir = "target/rust-analyzer-windows",
                }
            end
            return settings
        end,
        default_settings = {
            ["rust-analyzer"] = {
                checkOnSave = true,
                check = {
                    command = "check",
                    workspace = true,
                },
            },
        },
    },
}

vim.lsp.config("gopls", {
    settings = {
        gopls = {
            expandWorkspaceToModule = true,
        },
    },
})

vim.lsp.config("basedpyright", {
    -- Push workspace results so unopened files reach vim.diagnostic/Telescope
    -- without requiring a separate workspace/diagnostic pull request.
    init_options = {
        disablePullDiagnostics = true,
    },
    settings = {
        basedpyright = {
            analysis = {
                diagnosticMode = "workspace",
                -- Check types without requiring annotations throughout untyped code.
                typeCheckingMode = "standard",
            },
        },
    },
})

-- clangd reports source diagnostics for open files. Background indexing does
-- not publish project-wide diagnostics; use :CMakeDiagnostics[!] for build output.

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
        map("gd", function()
            require("telescope.builtin").lsp_definitions()
        end, "Goto definition")
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
        map("<leader>le", function()
            vim.diagnostic.open_float({ scope = "line" })
        end, "Line diagnostics")

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
