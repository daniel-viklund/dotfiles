-- Run from the repository root: nvim --headless -u NONE -l packages/neovim/.config/nvim-scratch/scripts/test-lazygit.lua
local api = vim.api
local config = vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")))
vim.opt.runtimepath:prepend(config)
local directory = vim.fn.tempname() .. "%20workspace"
local previous_cwd = vim.fn.getcwd()
local previous_config = vim.env.LG_CONFIG_FILE
local previous_config_dir = vim.env.CONFIG_DIR
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
  local lazygit_config = vim.fs.joinpath(directory, "lazygit-test.yml")
  vim.fn.writefile({
    "disableStartupPopups: true",
    "gui:",
    "  useHunkModeInStagingView: false",
  }, lazygit_config)
  vim.env.LG_CONFIG_FILE = lazygit_config
  vim.env.CONFIG_DIR = vim.fs.joinpath(directory, "lazygit-config")
  local alpha = vim.fs.joinpath(directory, "alpha")
  local simoon = vim.fs.joinpath(directory, "simoon-ui")
  local worktree = vim.fs.joinpath(directory, "worktree")
  init(alpha)
  init(simoon)
  vim.fn.writefile({ "alpha/", "simoon-ui/", "worktree/" }, vim.fs.joinpath(directory, ".gitignore"))
  git(directory, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
    "commit", "--quiet", "--allow-empty", "-m", "fixture")
  git(directory, "worktree", "add", "--quiet", "-b", "fixture-worktree", worktree)
  local simoon_file = vim.fs.joinpath(simoon, "a file's [test].txt")
  vim.fn.writefile({ "first", "second", "third", "fourth" }, simoon_file)
  git(simoon, "add", "--", simoon_file)
  git(simoon, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
    "commit", "--quiet", "-m", "fixture")
  vim.fn.writefile({ "first", "second", "changed", "fourth" }, simoon_file)
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
  end), "LazyGit UI must render:\n" .. table.concat(api.nvim_buf_get_lines(parent_buf, 0, -1, false), "\n"))
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
  assert(vim.wait(5000, function()
    return table.concat(api.nvim_buf_get_lines(simoon_buf, 0, -1, false), "\n"):find("a file's [test].txt", 1, true)
  end), "LazyGit must show the selected file")
  vim.fn.chansend(simoon_job, "2e")
  assert(vim.wait(5000, function()
    return not api.nvim_win_is_valid(popup)
      and vim.uv.fs_realpath(api.nvim_buf_get_name(0)) == vim.uv.fs_realpath(simoon_file)
  end), "LazyGit's e must open the selected file in the parent editor")
  assert(api.nvim_win_get_cursor(0)[1] == 3, "Files-panel editing must jump to the first change")
  assert(vim.fn.jobwait({ simoon_job }, 0)[1] == -1, "Editing must keep LazyGit alive")

  lazygit.open()
  assert(api.nvim_get_current_buf() == simoon_buf, "Returning from editing must reuse its repo")
  assert(job() == simoon_job)
  popup = api.nvim_get_current_win()
  vim.fn.chansend(simoon_job, "2\rjje")
  assert(vim.wait(5000, function() return not api.nvim_win_is_valid(popup) end),
    "Editing the selected diff line must hide the popup:\n"
      .. table.concat(api.nvim_buf_get_lines(simoon_buf, 0, -1, false), "\n"))
  assert(vim.uv.fs_realpath(api.nvim_buf_get_name(0)) == vim.uv.fs_realpath(simoon_file))
  assert(api.nvim_win_get_cursor(0)[1] == 4, "Diff editing must use the selected line, not the first change")
  assert(vim.fn.getcwd() == workspace_cwd, "Editing a nested repo's file must not change editor cwd")

  local function edit_selected_file(expected_line)
    lazygit.open()
    assert(job() == simoon_job)
    local editing_popup = api.nvim_get_current_win()
    vim.fn.chansend(simoon_job, "2Re")
    assert(vim.wait(5000, function() return not api.nvim_win_is_valid(editing_popup) end),
      "Files-panel editing must hide the popup")
    assert(api.nvim_win_get_cursor(0)[1] == expected_line, "Editing must select the first change")
  end
  git(simoon, "add", "--", simoon_file)
  api.nvim_win_set_cursor(0, { 1, 0 })
  edit_selected_file(3)
  vim.fn.writefile({ "first", "changed", "fourth" }, simoon_file)
  api.nvim_win_set_cursor(0, { 1, 0 })
  edit_selected_file(2)

  lazygit.open()
  assert(job() == simoon_job)
  popup = api.nvim_get_current_win()
  assert(not lazygit.edit_file(vim.fs.joinpath(simoon, "missing.txt")))
  assert(api.nvim_win_is_valid(popup), "An unreadable file must leave LazyGit open")
  assert(#notifications == 1 and notifications[1]:find("Cannot read file", 1, true))
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
  assert(#notifications == 2 and notifications[2]:find("No Git repository", 1, true))
end, debug.traceback)

for id in pairs(jobs) do
  if vim.fn.jobwait({ id }, 0)[1] == -1 then vim.fn.jobstop(id) end
end
vim.wait(100, function() return false end)
vim.fn.chdir(previous_cwd)
vim.env.LG_CONFIG_FILE = previous_config
vim.env.CONFIG_DIR = previous_config_dir
vim.fn.delete(directory, "rf")
if not ok then error(err) end
print("PASS: repo cycling, native e, quoted paths, diff lines, session reuse, workspace memory, and errors")
vim.cmd.qa({ bang = true })
