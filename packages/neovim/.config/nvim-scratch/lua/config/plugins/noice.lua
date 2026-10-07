vim.pack.add({
  "https://github.com/MunifTanjim/nui.nvim.git",
  "https://github.com/folke/noice.nvim.git",
})

-- Configure the backend before Noice takes over vim.notify.
require("config.plugins.notify")

require("noice").setup({
  commands = {
    history = {
      filter = {
        any = {
          { event = "notify" },
          { error = true },
          { warning = true },
          -- Neovim gives print/echo messages their own kinds.
          { event = "msg_show", kind = { "", "lua_print", "echo", "echomsg" } },
          { event = "lsp", kind = "message" },
        },
      },
    },
  },
  views = {
    notify = { backend = "notify" },
    split = {
      win_options = {
        winhighlight = { Normal = "Normal", NormalNC = "Normal" },
      },
    },
  },
  messages = {
    view = "notify",
    view_error = "notify",
    view_warn = "notify",
  },
  notify = {
    enabled = true,
    view = "notify",
  },
  lsp = {
    hover = {
      -- One server can return nothing while another provides documentation.
      silent = true,
    },
    -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
    override = {
      ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
      ["vim.lsp.util.stylize_markdown"] = true,
      ["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
    },
  },
  cmdline = {
	view = "cmdline"
  },
  -- you can enable a preset for easier configuration
  presets = {
    bottom_search = true, -- use a classic bottom cmdline for search
    command_palette = true, -- position the cmdline and popupmenu together
    long_message_to_split = true, -- long messages will be sent to a split
    inc_rename = false, -- enables an input dialog for inc-rename.nvim
    lsp_doc_border = true, -- add a border to hover docs and signature help
  },
})
