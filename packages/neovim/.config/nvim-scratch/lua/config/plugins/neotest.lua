vim.pack.add({
  "https://github.com/nvim-neotest/nvim-nio",
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/nvim-treesitter/nvim-treesitter",
  "https://github.com/nvim-neotest/neotest",
  "https://github.com/nvim-neotest/neotest-python",
  "https://github.com/nsidorenco/neotest-vstest",
})

-- Also recognize small unittest projects without pyproject.toml/setup.cfg.
-- The adapter uses this helper for both discovery and Python environment lookup.
local python = require("neotest-python.base")
python.get_root = require("neotest.lib").files.match_root_pattern(
  "pyproject.toml", "setup.cfg", "mypy.ini", "pytest.ini", "setup.py", "requirements.txt", ".git"
)

local neotest = require("neotest")
local adapter = require("neotest-python")({ dap = { justMyCode = false } })
local build_spec = adapter.build_spec
adapter.build_spec = function(args)
  local position = args.tree:data()
  local root = python.get_root(position.path) or vim.fn.getcwd()
  -- unittest's recursive discovery skips directories without __init__.py.
  -- Let Neotest run its discovered files individually in that case.
  if position.type == "dir" and python.get_runner(python.get_python_command(root)) == "unittest" then
    return nil
  end
  local spec = build_spec(args)
  spec.cwd = root
  if spec.strategy then spec.strategy.cwd = root end
  return spec
end

vim.g.neotest_vstest = { dap_settings = { type = "coreclr" }, broad_recursive_discovery = false }
local dotnet = require("neotest-vstest")
-- Prefer the whole solution, including modern .slnx files; standalone projects
-- still work when there is no solution file above them.
local match_root = require("neotest.lib").files.match_root_pattern
local function dotnet_root(path)
  return match_root("*.sln", "*.slnx")(path)
    or match_root("*.csproj", "*.fsproj")(path)
end

neotest.setup({
  -- Detect the project's virtualenv and use pytest when installed, else unittest.
  adapters = { adapter, dotnet },
  discovery = {
    filter_dir = function(name)
      return not vim.tbl_contains({ ".venv", "venv", "__pycache__", "node_modules" }, name)
    end,
  },
  summary = { open = "botright vsplit | vertical resize 45" },
  output = { open_on_run = false },
  output_panel = { open = "botright split | resize 12" },
  floating = { border = "rounded" },
})

-- Keep test actions together under <leader>t.
local mappings = {
  { "tn", function() neotest.run.run() end, "Run nearest test" },
  { "tf", function() neotest.run.run(vim.fn.expand("%:p")) end, "Run test file" },
  { "tt", function()
    local path = vim.fn.expand("%:p")
    local root = vim.bo.filetype == "cs" and dotnet_root(path) or python.get_root(path)
    neotest.run.run(root or vim.fn.getcwd())
    neotest.summary.open()
  end, "Run project tests" },
  { "tl", function() neotest.run.run_last() end, "Rerun last tests" },
  { "ts", function() neotest.summary.toggle() end, "Toggle test summary" },
  { "tx", function() neotest.run.stop() end, "Stop nearest test run" },
  { "td", function() neotest.run.run({ strategy = "dap" }) end, "Debug nearest test" },
  { "tj", function() neotest.jump.next({ status = "failed" }) end, "Next failed test" },
  { "tk", function() neotest.jump.prev({ status = "failed" }) end, "Previous failed test" },
}
for _, mapping in ipairs(mappings) do
  vim.keymap.set("n", "<leader>" .. mapping[1], mapping[2], { desc = mapping[3] })
end
