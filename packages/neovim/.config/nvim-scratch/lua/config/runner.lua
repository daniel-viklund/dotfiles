-- A project runner with one output terminal per command, starting at terminal 4.
local M = {}
local api = vim.api
local current, pending
local quitting = false
local pump
local launch_dir = vim.g.project_runner_launch_dir or vim.fn.getcwd()
local launch_root = vim.fs.normalize(vim.uv.fs_realpath(launch_dir) or launch_dir)

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Project runner" })
end

local function project_root()
  return launch_root
end

local function config_path(root)
  return vim.fs.joinpath(vim.fn.stdpath("data"), "project-runner", vim.fn.sha256(root) .. ".json")
end

local function run_commands(value)
  if type(value) == "string" then return value == "" and {} or { value } end
  if type(value) ~= "table" or not vim.islist(value) then return nil end
  for _, command in ipairs(value) do
    if type(command) ~= "string" or vim.trim(command) == "" then return nil end
  end
  return value
end

local function read_config(root)
  local path = config_path(root)
  if vim.fn.filereadable(path) == 0 then
    return { build = "", run = "", cwd = "." }
  end
  local ok, config = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
  end)
  if not ok or type(config) ~= "table"
    or type(config.build) ~= "string" or not run_commands(config.run)
    or type(config.cwd) ~= "string" then
    notify("Invalid runner settings: " .. path, vim.log.levels.ERROR)
    return
  end
  return config
end

local function working_directory(root, value)
  local path = vim.fs.normalize(value == "" and "." or value)
  if not path:match("^/") and not path:match("^%a:[/\\]") then
    path = vim.fs.joinpath(root, path)
  end
  return vim.fs.normalize(path)
end

local function configure(root, done)
  local config = read_config(root)
  if not config then return end
  local previous = run_commands(config.run)
  local commands = {}
  local function save()
    if vim.fn.isdirectory(working_directory(root, config.cwd)) == 0 then
      notify("Working directory does not exist", vim.log.levels.ERROR)
      return
    end
    config.root = root
    local path = config_path(root)
    local ok, err = pcall(function()
      vim.fn.mkdir(vim.fs.dirname(path), "p")
      assert(vim.fn.writefile({ vim.json.encode(config) }, path) == 0, "Could not save settings")
    end)
    if not ok then
      notify(tostring(err), vim.log.levels.ERROR)
      return
    end
    notify("Saved commands for " .. root)
    if done then done(config) end
  end
  local function prompt_run(index)
    local prompt = index == 1 and "Run command 1 (blank for build only): "
      or "Run command " .. index .. " (separate terminal; blank to finish): "
    vim.ui.input({ prompt = prompt, default = previous[index] or "" }, function(value)
      if value == nil then return end
      value = vim.trim(value)
      if value ~= "" then
        commands[#commands + 1] = value
        prompt_run(index + 1)
        return
      end
      config.run = #commands == 1 and commands[1] or commands
      vim.ui.input({ prompt = "Working directory (relative to " .. root .. "): ",
        default = config.cwd, completion = "dir" }, function(cwd)
        if cwd == nil then return end
        config.cwd = vim.trim(cwd)
        save()
      end)
    end)
  end
  vim.ui.input({ prompt = "Build command (blank to skip): ", default = config.build }, function(value)
    if value == nil then return end
    config.build = vim.trim(value)
    prompt_run(1)
  end)
end

function M.configure()
  configure(project_root())
end

local function stop_current()
  if not current then return end
  -- Cancel a queued build -> run transition as well as a running process.
  current.cancelled = true
  for _, job in ipairs(current.jobs) do
    if job.running and not job.stopping then
      job.stopping = true
      vim.fn.jobstop(job.term.job_id)
    end
  end
end

function M.stop()
  pending = nil
  stop_current()
end

pump = function()
  if quitting or not pending or (current and current.running > 0) then return end
  local request = pending
  pending = nil
  local terminals = require("toggleterm.terminal")
  local occupied = terminals.get(4, true)
  if occupied and (not current or occupied ~= current.jobs[1].term) then
    notify("Terminal 4 is in use. Close its shell with exit before using the runner.", vim.log.levels.WARN)
    return
  end
  if current then
    for _, job in ipairs(current.jobs) do job.term:shutdown() end
  end

  local state = { jobs = {}, running = 0 }
  current = state
  local commands = request.phase == "build" and { request.config.build } or run_commands(request.config.run)
  local id = 4
  for index, command in ipairs(commands) do
    while terminals.get(id, true) do id = id + 1 end
    local job = { running = true }
    state.jobs[#state.jobs + 1] = job
    state.running = state.running + 1
    local label = request.phase == "run" and #commands > 1 and "run " .. index or request.phase
    job.term = terminals.Terminal:new({
      count = id,
      cmd = command,
      dir = request.cwd,
      direction = "horizontal",
      display_name = label .. " · " .. command,
      close_on_exit = false,
      on_exit = function(_, _, code)
        if not job.running then return end
        job.running = false
        state.running = state.running - 1
        -- ToggleTerm finishes its TermClose handling before a replacement starts.
        vim.schedule(function()
          if quitting or current ~= state then return end
          if not state.cancelled then
            if code ~= 0 then
              notify(label .. " exited with code " .. code, vim.log.levels.ERROR)
            elseif request.phase == "build" then
              notify("Build succeeded")
              if request.run_after then
                pending = vim.tbl_extend("force", request, { phase = "run", run_after = false })
              end
            end
          end
          pump()
        end)
      end,
    })

    local ok, err = pcall(function() job.term:open() end)
    if not ok or not job.term.job_id or job.term.job_id <= 0 then
      if job.running then
        job.running = false
        state.running = state.running - 1
      end
      stop_current()
      notify("Could not start " .. label .. ": " .. tostring(err or "terminal did not start"), vim.log.levels.ERROR)
      break
    end
    id = id + 1
  end
  -- Show output while keeping editing shortcuts available in the source window.
  vim.schedule(function()
    if current == state and api.nvim_win_is_valid(request.window)
      and vim.iter(state.jobs):any(function(job)
        return api.nvim_get_current_win() == job.term.window
          and api.nvim_win_get_buf(request.window) ~= job.term.bufnr
      end) then
      api.nvim_set_current_win(request.window)
      vim.cmd.stopinsert()
    end
  end)
end

function M.execute(action)
  assert(action == "build" or action == "run" or action == "build_run", "Unknown runner action")
  local root = project_root()
  local window = api.nvim_get_current_win()
  local config = read_config(root)
  if not config then return end
  local function start(settings)
    local phase = action == "build" and "build" or "run"
    if action == "build_run" and settings.build ~= "" then phase = "build" end
    if (phase == "build" and settings.build == "")
      or (action ~= "build" and #run_commands(settings.run) == 0) then
      notify("Command is empty. Configure it with <leader>pc.", vim.log.levels.WARN)
      return
    end
    local cwd = working_directory(root, settings.cwd)
    if vim.fn.isdirectory(cwd) == 0 then
      notify("Working directory does not exist: " .. cwd, vim.log.levels.ERROR)
      return
    end
    pending = {
      root = root, config = settings, cwd = cwd, window = window,
      phase = phase, run_after = action == "build_run" and phase == "build",
    }
    stop_current()
    pump()
  end
  local needs_config = (action == "build" and config.build == "")
    or (action ~= "build" and #run_commands(config.run) == 0)
  if needs_config then configure(root, start) else start(config) end
end

function M.terminal()
  return current and current.jobs[1] and current.jobs[1].term
end

function M.terminals()
  local result = {}
  for _, job in ipairs(current and current.jobs or {}) do result[#result + 1] = job.term end
  return result
end

function M.reserves(id)
  return id == 4 or vim.iter(M.terminals()):any(function(term) return term.id == id end)
end

function M.toggle()
  local output = vim.tbl_filter(function(term)
    return term.bufnr and api.nvim_buf_is_valid(term.bufnr)
  end, M.terminals())
  if #output > 0 then
    -- Keep objects even after exit: ToggleTerm removes finished jobs from its registry.
    local visible = vim.iter(output):any(function(term) return term:is_open() end)
    for _, term in ipairs(output) do
      if visible then
        if term:is_open() then term:close() end
      else
        term:open()
      end
    end
  else
    notify("No runner output yet. Use <leader>pr to run or <leader>pb to build.")
  end
end

function M.setup()
  local mappings = {
    { "pb", function() M.execute("build") end, "Build project" },
    { "pr", function() M.execute("run") end, "Run/restart project" },
    { "pR", function() M.execute("build_run") end, "Build and run project" },
    { "px", M.stop, "Stop project" },
    { "pc", M.configure, "Configure project commands" },
    { "t4", M.toggle, "Toggle project output terminals" },
  }
  for _, mapping in ipairs(mappings) do
    vim.keymap.set("n", "<leader>" .. mapping[1], mapping[2], { desc = mapping[3] })
  end
  api.nvim_create_autocmd("VimLeavePre", {
    group = api.nvim_create_augroup("ProjectRunner", { clear = true }),
    callback = function()
      quitting = true
      M.stop()
    end,
  })
end

return M
