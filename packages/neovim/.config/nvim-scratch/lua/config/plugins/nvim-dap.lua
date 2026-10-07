-- The alphabetical loader configures mason.lua before this file.
local system = vim.uv.os_uname()
local apple_silicon = system.sysname == 'Darwin'
  and (system.machine == 'arm64' or system.machine == 'aarch64')

local plugins = {
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/nvim-neotest/nvim-nio',
  'https://github.com/rcarriga/nvim-dap-ui',
  'https://github.com/jay-babu/mason-nvim-dap.nvim',
  'https://github.com/leoluz/nvim-dap-go',
}

if apple_silicon then
  plugins[#plugins + 1] = 'https://github.com/Cliffback/netcoredbg-macOS-arm64.nvim'
end
vim.pack.add(plugins)

-- F-key stepping binds
vim.keymap.set('n', '<F5>', function() require('dap').continue() end, { desc = 'Debug: Start/Continue' })
vim.keymap.set('n', '<F11>', function() require('dap').step_into() end, { desc = 'Debug: Step Into' })
vim.keymap.set('n', '<F10>', function() require('dap').step_over() end, { desc = 'Debug: Step Over' })
vim.keymap.set('n', '<F12>', function() require('dap').step_out() end, { desc = 'Debug: Step Out' })
vim.keymap.set('n', '<F9>', function() require('dap').toggle_breakpoint() end, { desc = 'Debug: Toggle Breakpoint' })
-- <C-F9> gets recieved as F33 by nvim
vim.keymap.set('n', '<F33>', function() require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, { desc = 'Debug: Conditional Breakpoint' })

-- Debugging keymaps under <leader>d
vim.keymap.set('n', '<leader>dt', function() require('dap').terminate() end, { desc = 'Debug: Terminate' })
-- Evaluate expressions: word under cursor (normal) or selection (visual).
-- Press <leader>de a second time to jump into the float and expand values.
vim.keymap.set({ 'n', 'v' }, '<leader>de', function() require('dapui').eval() end, { desc = 'Debug: Eval Expression' })
vim.keymap.set('n', '<leader>dE', function() require('dapui').eval(vim.fn.input 'Expression: ') end, { desc = 'Debug: Eval Input' })
-- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
vim.keymap.set('n', '<leader>du', function() require('dapui').toggle() end, { desc = 'Debug: Toggle UI' })

local dap = require 'dap'
local dapui = require 'dapui'
local mason_dap = require 'mason-nvim-dap'

local ensure_installed = { 'delve', 'codelldb' , 'debugpy'}
if not apple_silicon then
  -- mason-nvim-dap calls the standard netcoredbg adapter "coreclr".
  ensure_installed[#ensure_installed + 1] = 'coreclr'
end

mason_dap.setup {
  ensure_installed = ensure_installed,
  automatic_installation = apple_silicon and { exclude = { 'coreclr' } } or true,
  handlers = {
    coreclr = function(config)
      -- Even a later Mason install must not replace the Apple Silicon adapter.
      if not apple_silicon then
        mason_dap.default_setup(config)
      end
    end,
  },
}

-- Dap UI setup
-- For more information, see |:help nvim-dap-ui|
---@diagnostic disable-next-line: missing-fields
dapui.setup {
  controls = {
    element = 'repl',
    enabled = true,
    icons = {
      disconnect = '',
      pause = '',
      play = '',
      run_last = '',
      step_back = '',
      step_into = '',
      step_out = '',
      step_over = '',
      terminate = '',
    },
  },
  element_mappings = {},
  expand_lines = true,
  floating = {
    border = 'single',
    mappings = {
      close = { 'q', '<Esc>' },
    },
  },
  force_buffers = true,
  icons = {
    collapsed = '',
    current_frame = '',
    expanded = '',
  },
  layouts = {
    {
      elements = {
        { id = 'stacks', size = 0.5 },
        { id = 'console', size = 0.5 },
      },
      position = 'left',
      size = 40,
    },
    {
      elements = {
        { id = 'scopes', size = 1.0 },
      },
      position = 'bottom',
      size = 10,
    },
  },
  mappings = {
    edit = 'e',
    expand = { '<CR>', '<2-LeftMouse>' },
    open = 'o',
    remove = 'd',
    repl = 'r',
    toggle = 't',
  },
  render = {
    indent = 1,
    max_value_lines = 100,
  },
}

-- Change breakpoint icons
-- vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
-- vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
-- local breakpoint_icons = vim.g.have_nerd_font
--     and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
--   or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
-- for type, icon in pairs(breakpoint_icons) do
--   local tp = 'Dap' .. type
--   local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
--   vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
-- end

dap.listeners.after.event_initialized['dapui_config'] = dapui.open
dap.listeners.before.event_terminated['dapui_config'] = dapui.close
dap.listeners.before.event_exited['dapui_config'] = dapui.close

-- Install golang specific config
require('dap-go').setup {
  delve = {
    -- On Windows delve must be run attached or it crashes.
    -- See https://github.com/leoluz/nvim-dap-go/blob/main/README.md#configuring
    detached = vim.fn.has 'win32' == 0,
  },
}

if apple_silicon then
  require('netcoredbg-macOS-arm64').setup(dap)
end
