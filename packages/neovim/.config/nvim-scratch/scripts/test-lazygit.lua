-- Run from the repository root: nvim --headless -u NONE -l packages/neovim/.config/nvim-scratch/scripts/test-lazygit.lua
local api = vim.api
local config = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))
vim.opt.runtimepath:prepend(config)
local directory = vim.fn.tempname()
local previous_cwd = vim.fn.getcwd()
local jobs = {}
local notifications = {}
vim.notify = function(message) notifications[#notifications + 1] = message end

local function git(path, ...)
  local command = { "git", "-C", path }
  vim.list_extend(command, { ... })
  local result = vim.system(command, { text = true }):wait()
  assert(result.code == 0, result.stderr)
end

local function init(path)
  vim.fn.mkdir(path, "p")
  git(path, "init", "--quiet")
end

local function job()
  local id = vim.b.terminal_job_id
  assert(id and vim.fn.jobwait({ id }, 0)[1] == -1, "LazyGit must be running")
  jobs[id] = true
  return id
end

local function cycle(key)
  local mapping = vim.fn.maparg(key, "t", false, true)
  assert(mapping.buffer == 1 and type(mapping.callback) == "function")
  mapping.callback()
end

local ok, err = xpcall(function()
  init(directory)
  local alpha = vim.fs.joinpath(directory, "alpha")
  local simoon = vim.fs.joinpath(directory, "simoon-ui")
  local worktree = vim.fs.joinpath(directory, "worktree")
  init(alpha)
  init(simoon)
  vim.fn.writefile({ "alpha/", "simoon-ui/", "worktree/" }, vim.fs.joinpath(directory, ".gitignore"))
  git(directory, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
    "commit", "--quiet", "--allow-empty", "-m", "fixture")
  git(directory, "worktree", "add", "--quiet", "-b", "fixture-worktree", worktree)
  vim.fn.writefile({ "fixture" }, vim.fs.joinpath(simoon, "file.txt"))
  vim.fn.chdir(directory)
  local workspace_cwd = vim.fn.getcwd()

  local lazygit = require("config.lazygit")
  lazygit.open()
  local popup = api.nvim_get_current_win()
  local parent_buf = api.nvim_get_current_buf()
  local parent_job = job()
  assert(api.nvim_win_get_config(popup).title[1][1]:find("[1/4]", 1, true))
  assert(vim.wait(5000, function()
    return table.concat(api.nvim_buf_get_lines(parent_buf, 0, -1, false), "\n"):find("Files", 1, true)
  end), "LazyGit UI must render")
  cycle("<M-]>")
  local alpha_buf = api.nvim_get_current_buf()
  job()
  assert(alpha_buf ~= parent_buf)
  cycle("<M-]>")
  local simoon_buf = api.nvim_get_current_buf()
  local simoon_job = job()
  assert(api.nvim_win_get_config(popup).title[1][1]:find("simoon-ui [3/4]", 1, true))
  assert(api.nvim_get_current_win() == popup, "Cycling must reuse the popup")
  assert(vim.fn.getcwd() == workspace_cwd, "Cycling must not change the editor's working directory")
  cycle("<M-]>")
  job()
  assert(api.nvim_win_get_config(popup).title[1][1]:find("worktree [4/4]", 1, true))
  cycle("<M-]>")
  assert(api.nvim_get_current_buf() == parent_buf, "Next must wrap")
  assert(job() == parent_job, "Cycling must preserve the running session")
  cycle("<M-[>")
  cycle("<M-[>")
  assert(api.nvim_get_current_buf() == simoon_buf, "Previous must wrap")
  assert(job() == simoon_job)
  api.nvim_win_close(popup, true)

  vim.cmd.edit(vim.fn.fnameescape(vim.fs.joinpath(simoon, "file.txt")))
  lazygit.open()
  assert(api.nvim_get_current_buf() == simoon_buf, "File-relative opening must reuse its repo")
  assert(job() == simoon_job)
  popup = api.nvim_get_current_win()
  vim.fn.chansend(simoon_job, "q")
  assert(vim.wait(5000, function() return not api.nvim_win_is_valid(popup) end),
    "Quitting LazyGit must close the popup")
  assert(vim.fn.jobwait({ parent_job }, 0)[1] == -1, "Other repo sessions must survive")

  vim.cmd.enew()
  lazygit.open()
  assert(api.nvim_win_get_config(0).title[1][1]:find("simoon-ui [3/4]", 1, true),
    "Reopening after quit must remember the selected repo without a file")
  local resumed_job = job()
  assert(resumed_job ~= simoon_job, "Quitting must restart only the selected session")
  api.nvim_win_close(api.nvim_get_current_win(), true)

  local another = vim.fs.joinpath(directory, "another")
  init(another)
  vim.fn.chdir(another)
  vim.cmd.enew()
  lazygit.open()
  local another_buf = api.nvim_get_current_buf()
  job()
  assert(api.nvim_win_get_config(0).title[1][1]:find("another [1/1]", 1, true),
    "Another workspace must not inherit the previous selection")
  api.nvim_win_close(api.nvim_get_current_win(), true)
  vim.fn.chdir(directory)
  vim.cmd.edit(vim.fn.fnameescape(vim.fs.joinpath(another, "file.txt")))
  lazygit.open()
  assert(job() == resumed_job, "Returning must remember the repo by path, not index or current file")
  assert(api.nvim_win_get_config(0).title[1][1]:find("simoon-ui [4/5]", 1, true))
  popup = api.nvim_get_current_win()
  vim.fn.chansend(resumed_job, "q")
  assert(vim.wait(5000, function() return not api.nvim_win_is_valid(popup) end))
  assert(vim.uv.fs_rename(vim.fs.joinpath(simoon, ".git"), vim.fs.joinpath(simoon, ".git-disabled")))
  vim.cmd.enew()
  lazygit.open()
  assert(api.nvim_get_current_buf() == parent_buf, "A removed repo must fall back to the current repo")
  api.nvim_win_close(api.nvim_get_current_win(), true)
  vim.fn.chdir(another)
  vim.cmd.enew()
  lazygit.open()
  assert(api.nvim_get_current_buf() == another_buf, "Workspace selections must remain independent")
  api.nvim_win_close(api.nvim_get_current_win(), true)

  vim.fn.chdir(vim.fs.dirname(directory))
  vim.cmd.enew()
  lazygit.open()
  assert(#notifications == 1 and notifications[1]:find("No Git repository", 1, true))
end, debug.traceback)

for id in pairs(jobs) do
  if vim.fn.jobwait({ id }, 0)[1] == -1 then vim.fn.jobstop(id) end
end
vim.wait(100, function() return false end)
vim.fn.chdir(previous_cwd)
vim.fn.delete(directory, "rf")
if not ok then error(err) end
print("PASS: repo cycling, quit/reopen, per-workspace selection, reordered/removed repos, and missing-repo errors")
vim.cmd.qa({ bang = true })
