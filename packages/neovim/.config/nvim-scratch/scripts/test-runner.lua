-- Run with: nvim --headless -u NONE -l scripts/test-runner.lua
-- Requires the installed ToggleTerm plugin and Python 3 for process fixtures.
-- The process fixtures use POSIX signals (macOS/Linux).
local api, fn = vim.api, vim.fn
local source = fn.getcwd()
local temporary = fn.tempname() .. " runner space"
local runner
local original_stdpath, original_input, original_notify = fn.stdpath, vim.ui.input, vim.notify
local messages = {}

local function wait_for(description, predicate)
  assert(vim.wait(6000, predicate, 10), "Timed out: " .. description)
end

local function read(path)
  return fn.filereadable(path) == 1 and table.concat(fn.readfile(path), "\n") or ""
end

local function main()
  vim.o.lines = 50
  fn.mkdir(temporary, "p")
  temporary = assert(vim.uv.fs_realpath(temporary))
  vim.g.project_runner_launch_dir = temporary .. "/project"
  fn.mkdir(vim.g.project_runner_launch_dir .. "/app", "p")
  vim.opt.runtimepath:prepend(source)
  vim.cmd.packadd("toggleterm.nvim")
  fn.stdpath = function(kind)
    return kind == "data" and temporary .. "/data" or original_stdpath(kind)
  end
  vim.notify = function(message, level)
    messages[#messages + 1] = { message = message, level = level }
  end
  require("config.keymaps")
  local pack_add = vim.pack.add
  vim.pack.add = function() end -- Plugin is already loaded; test without installing anything.
  require("config.plugins.toggleterm")
  vim.pack.add = pack_add
  runner = require("config.runner")

  local project = temporary .. "/project"
  local other = temporary .. "/other"
  fn.mkdir(temporary .. "/.git", "p") -- An ancestor Git root must not override the launch directory.
  fn.mkdir(project .. "/app", "p")
  fn.mkdir(other .. "/.git", "p")
  fn.writefile({ "source" }, project .. "/app/main.txt")
  fn.writefile({ "source" }, other .. "/main.txt")
  local python = fn.exepath("python3")
  assert(python ~= "", "Python 3 is required")
  local worker = temporary .. "/worker.py"
  fn.writefile(vim.split([[
import os, pathlib, signal, subprocess, sys, time
directory = pathlib.Path(sys.argv[1])
mode = sys.argv[2]
def record(name, value):
    with (directory / name).open("a") as output:
        output.write(str(value) + "\n")
if mode == "build":
    record("builds", os.getcwd())
    print("BUILD OUTPUT", flush=True)
    time.sleep(float(sys.argv[4]))
    sys.exit(int(sys.argv[3]))
if mode == "run":
    record("runs", os.getcwd())
    print("RUN OUTPUT", flush=True)
    sys.exit(0)
if mode == "child":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    (directory / "child-ready").write_text(str(os.getpid()))
else:
    child = subprocess.Popen([sys.executable, __file__, str(directory), "child"])
    def stop(*_):
        # Give shutdown observable duration, exercising restart queuing.
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        signal.signal(signal.SIGHUP, signal.SIG_IGN)
        time.sleep(0.15)
        child.wait(timeout=2)
        record("stops", os.getpid())
        sys.exit(0)
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGHUP, stop)
    record("starts", os.getpid())
    print(directory.name + " STDOUT", flush=True)
    print(directory.name + " STDERR", file=sys.stderr, flush=True)
while True:
    time.sleep(0.05)
]], "\n"), worker)

  local function command(mode, arguments, directory)
    return table.concat({ fn.shellescape(python), fn.shellescape(worker), fn.shellescape(directory or project), mode,
      arguments or "" }, " ")
  end
  local function configure(build, run, cwd)
    local values = { build }
    for _, cmd in ipairs(type(run) == "table" and run or (run == "" and {} or { run })) do
      values[#values + 1] = cmd
    end
    values[#values + 1] = ""
    values[#values + 1] = cwd or "app"
    local index = 0
    vim.ui.input = function(_, callback)
      index = index + 1
      callback(values[index])
    end
    runner.configure()
    assert(index == #values, "Unexpected configuration prompts")
  end
  local function output()
    local result = {}
    for _, buf in ipairs(api.nvim_list_bufs()) do
      if api.nvim_buf_is_loaded(buf) and vim.b[buf].toggle_number == 4 then
        result[#result + 1] = table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
      end
    end
    return table.concat(result, "\n")
  end
  local function settled()
    wait_for("runner exit", function()
      return vim.iter(runner.terminals()):all(function(term)
        return require("toggleterm.terminal").get(term.id, true) == nil
      end)
    end)
    vim.wait(100, function() return false end, 10)
  end
  local function edit(path)
    vim.cmd.edit(fn.fnameescape(path))
  end

  -- Use the launch directory despite another buffer's Git root and a changed cwd.
  vim.cmd.cd(fn.fnameescape(other))
  edit(other .. "/main.txt")
  local source_window = api.nvim_get_current_win()
  configure(command("build", "0 0"), command("run"))
  assert(#fn.glob(temporary .. "/data/project-runner/*.json", false, true) == 1)
  vim.ui.input = function() error("Saved commands should not prompt again") end
  runner.execute("build_run")
  wait_for("build then run", function() return read(project .. "/runs") ~= "" end)
  settled()
  assert(read(project .. "/builds") == project .. "/app")
  assert(read(project .. "/runs") == project .. "/app")
  assert(output():find("RUN OUTPUT", 1, true), "Finished output was lost")
  assert(api.nvim_get_current_win() == source_window, "Launch stole editor focus")
  runner.toggle() -- Hide the completed output, then reopen it without executing again.
  runner.toggle()
  assert(read(project .. "/runs") == project .. "/app", "Toggling output reran the command")
  api.nvim_set_current_win(source_window)
  vim.cmd.stopinsert()

  -- Hide/restore shells together with finished project output, without rerunning either.
  local terminals = require("toggleterm.terminal")
  local shell = terminals.Terminal:new({ count = 1, cmd = "cat" })
  local hidden = terminals.Terminal:new({ count = 2, cmd = "cat" })
  hidden:open()
  hidden:close()
  shell:open()
  local shell_job = shell.job_id
  local project_term = runner.terminal()
  local toggle_all = fn.maparg("<leader>tt", "n", false, true).callback
  api.nvim_win_set_height(shell.window, 2)
  toggle_all()
  assert(not shell:is_open() and not project_term:is_open(), "Did not hide both terminals")
  assert(vim.uv.kill(fn.jobpid(shell_job), 0) == 0, "Hiding stopped the shell")
  toggle_all()
  assert(shell:is_open() and project_term:is_open(), "Did not restore both terminals")
  assert(api.nvim_win_get_height(shell.window) == 15, "Shell retained its compressed height")
  assert(api.nvim_win_get_height(project_term.window) == 15, "Project retained its compressed height")
  assert(not hidden:is_open(), "Restored a terminal that was already hidden")
  assert(shell.job_id == shell_job, "Restoring restarted the shell")
  assert(read(project .. "/runs") == project .. "/app", "Restoring reran the project")
  shell:shutdown()
  hidden:shutdown()
  api.nvim_set_current_win(source_window)
  vim.cmd.stopinsert()

  -- Failed builds retain their output and never launch the run command.
  configure(command("build", "7 0"), command("run"))
  runner.execute("build_run")
  wait_for("failed build", function()
    return vim.iter(messages):any(function(item) return item.message == "build exited with code 7" end)
  end)
  settled()
  assert(read(project .. "/runs") == project .. "/app", "Ran after a failed build")
  assert(output():find("BUILD OUTPUT", 1, true), "Failed build output was lost")

  -- Cancel a running build, including the queued run phase.
  configure(command("build", "0 2"), command("run"))
  runner.execute("build_run")
  wait_for("slow build", function() return output():find("BUILD OUTPUT", 1, true) ~= nil end)
  runner.stop()
  settled()
  assert(read(project .. "/runs") == project .. "/app", "Stop did not cancel build/run")

  -- Restart real processes, including a child, and coalesce repeated requests.
  configure("", command("serve"))
  runner.execute("run")
  wait_for("server and child", function() return read(project .. "/child-ready") ~= "" end)
  local first = tonumber(read(project .. "/starts"))
  local child = tonumber(read(project .. "/child-ready"))
  runner.execute("run")
  runner.execute("run")
  runner.execute("run")
  wait_for("one replacement server", function() return #fn.readfile(project .. "/starts") == 2 end)
  wait_for("replacement child", function() return tonumber(read(project .. "/child-ready")) ~= child end)
  assert(vim.uv.kill(first, 0) == nil, "Old parent survived restart")
  assert(vim.uv.kill(child, 0) == nil, "Old child survived restart")
  assert(#fn.readfile(project .. "/stops") == 1, "Restart overlapped the old process")
  runner.execute("run")
  runner.stop() -- Cancel a queued restart before the old process finishes.
  settled()
  assert(#fn.readfile(project .. "/starts") == 2, "Stop did not cancel the pending restart")

  -- Multiple foreground commands have independent output and share stop/restart.
  local client, server = project .. "/client", project .. "/server"
  fn.mkdir(client, "p")
  fn.mkdir(server, "p")
  local commands = { command("serve", nil, server), command("serve", nil, client) }
  configure(command("build", "7 0"), commands)
  runner.execute("build_run")
  settled()
  assert(read(server .. "/starts") == "" and read(client .. "/starts") == "", "Ran after failed build")
  configure(command("build", "0 0"), commands)
  package.loaded["config.runner"] = nil
  runner = require("config.runner")
  runner.setup()
  vim.ui.input = function() error("Multiple commands did not persist") end
  local occupied = terminals.Terminal:new({ count = 5, cmd = "cat" })
  occupied:open()
  occupied:close()
  api.nvim_set_current_win(source_window)
  vim.cmd.stopinsert()
  runner.execute("build_run")
  wait_for("both processes and children", function()
    return read(server .. "/child-ready") ~= "" and read(client .. "/child-ready") ~= ""
  end)
  local outputs = runner.terminals()
  assert(#outputs == 2 and outputs[1].id == 4 and outputs[2].id == 6, "Overwrote an occupied terminal")
  wait_for("independent stdout/stderr", function()
    for i, name in ipairs({ "server", "client" }) do
      local lines = table.concat(api.nvim_buf_get_lines(outputs[i].bufnr, 0, -1, false), "\n")
      if not lines:find(name .. " STDOUT", 1, true) or not lines:find(name .. " STDERR", 1, true) then
        return false
      end
      local other_name = i == 1 and "client" or "server"
      assert(not lines:find(other_name .. " STDOUT", 1, true), "Output was mixed")
    end
    return true
  end)
  assert(api.nvim_get_current_win() == source_window, "Multiple launches stole focus")
  local old_pids = {}
  for _, directory in ipairs({ server, client }) do
    old_pids[#old_pids + 1] = tonumber(read(directory .. "/starts"))
    old_pids[#old_pids + 1] = tonumber(read(directory .. "/child-ready"))
  end
  runner.execute("run")
  runner.execute("run")
  runner.execute("run")
  wait_for("both replacement processes", function()
    return #fn.readfile(server .. "/starts") == 2 and #fn.readfile(client .. "/starts") == 2
      and tonumber(read(server .. "/child-ready")) ~= old_pids[2]
      and tonumber(read(client .. "/child-ready")) ~= old_pids[4]
  end)
  for _, pid in ipairs(old_pids) do assert(vim.uv.kill(pid, 0) == nil, "Old process survived restart") end
  runner.execute("run")
  runner.stop()
  settled()
  assert(#fn.readfile(server .. "/starts") == 2 and #fn.readfile(client .. "/starts") == 2,
    "Stop did not cancel a multiple-command restart")
  outputs = runner.terminals()
  assert(runner.reserves(outputs[2].id), "Finished output ID was not reserved")
  for _, toggle in ipairs({ runner.toggle, toggle_all }) do
    toggle()
    assert(not outputs[1]:is_open() and not outputs[2]:is_open(), "Did not hide both outputs")
    toggle()
    assert(outputs[1]:is_open() and outputs[2]:is_open(), "Did not restore both finished outputs")
  end
  assert(#fn.readfile(server .. "/starts") == 2 and #fn.readfile(client .. "/starts") == 2,
    "Restoring finished output reran commands")
  assert(vim.uv.kill(fn.jobpid(occupied.job_id), 0) == 0, "Stopped an unrelated shell")
  occupied:shutdown()
  api.nvim_set_current_win(source_window)
  vim.cmd.stopinsert()

  -- A failed run command leaves its sibling alive, and stop still reaches it.
  local survivor = project .. "/survivor"
  fn.mkdir(survivor, "p")
  configure("", { command("build", "9 0"), command("serve", nil, survivor) })
  runner.execute("run")
  wait_for("failed command and surviving sibling", function()
    return read(survivor .. "/child-ready") ~= "" and vim.iter(messages):any(function(item)
      return item.message == "run 1 exited with code 9"
    end)
  end)
  local survivor_pid = tonumber(read(survivor .. "/starts"))
  local survivor_child = tonumber(read(survivor .. "/child-ready"))
  assert(vim.uv.kill(survivor_pid, 0) == 0, "Failure stopped the other command")
  runner.stop()
  settled()
  assert(vim.uv.kill(survivor_pid, 0) == nil and vim.uv.kill(survivor_child, 0) == nil,
    "Stop missed a surviving command or its child")

  -- Settings persist across module reloads and stay separate for each project.
  configure("", command("run"))
  package.loaded["config.runner"] = nil
  runner = require("config.runner")
  runner.setup()
  vim.ui.input = function() error("Persistence failed") end
  runner.execute("build_run") -- An empty build command is optional.
  wait_for("run with no build", function() return #fn.readfile(project .. "/runs") == 2 end)
  settled()
  -- Simulate launching a new Neovim session in a different folder.
  vim.g.project_runner_launch_dir = other
  package.loaded["config.runner"] = nil
  runner = require("config.runner")
  runner.setup()
  edit(other .. "/main.txt")
  configure("", command("run"), ".")
  runner.execute("run")
  wait_for("other project", function() return read(project .. "/runs"):find(other, 1, true) ~= nil end)
  settled()
  assert(#fn.glob(temporary .. "/data/project-runner/*.json", false, true) == 2)

  -- Canceling a prompt leaves the previously saved commands untouched.
  vim.ui.input = function(_, callback) callback(nil) end
  runner.configure()
  vim.ui.input = function() error("Cancel discarded saved settings") end
  runner.execute("run")
  wait_for("run after canceled configure", function() return #fn.readfile(project .. "/runs") == 4 end)
  settled()
  print("Project runner integration checks passed")
end

local ok, err = xpcall(main, debug.traceback)
if runner then runner.stop() end
vim.wait(300, function() return false end, 10)
fn.stdpath, vim.ui.input, vim.notify = original_stdpath, original_input, original_notify
fn.delete(temporary, "rf")
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
