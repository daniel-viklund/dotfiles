-- Capture the launch directory before plugins can change Neovim's cwd.
vim.g.project_runner_launch_dir = vim.fn.getcwd()

-- Archive tools installed on Windows are exposed only to this Neovim process.
if vim.fn.has("win32") == 1 then
  local path_file = vim.fs.joinpath(vim.fn.stdpath("config"), "windows-path.txt")
  if vim.fn.filereadable(path_file) == 1 then
    local extra_paths = table.concat(vim.fn.readfile(path_file), ";")
    vim.env.PATH = extra_paths .. ";" .. vim.env.PATH
  end
end

require("config.keymaps")
require("config.options")
require("config.plugins")
require("config.start")
