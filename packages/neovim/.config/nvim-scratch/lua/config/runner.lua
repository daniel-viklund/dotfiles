-- Project jobs publish named output buffers in the terminal panel.
local M = {}
local api = vim.api
local active, pending = {}, {}
local last_phase
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
    vim.ui.input({ prompt = prompt, default = previous[index] or "", completion = "shellcmdline" }, function(value)
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
  vim.ui.input({ prompt = "Build command (blank to skip): ", default = config.build,
    completion = "shellcmdline" }, function(value)
    if value == nil then return end
    config.build = vim.trim(value)
    prompt_run(1)
  end)
end

function M.configure()
  configure(project_root())
end

local function stop_state(state)
  if not state then return end
  -- Cancel a queued build -> run transition as well as a running process.
  state.cancelled = true
  for _, job in ipairs(state.jobs) do
    if job.running and not job.stopping and job.term then
      job.stopping = true
      vim.fn.jobstop(job.term.job_id)
    end
  end
end

local function stop_current()
  for _, state in pairs(active) do stop_state(state) end
end

function M.stop()
  pending = {}
  stop_current()
end

pump = function(role)
  if quitting then return end
  if not role then
    pump("build")
    pump("run")
    return
  end
  local current = active[role]
  if not pending[role] or (current and current.running > 0) then return end
  if role == "build" and pending.build.run_after and active.run and active.run.running > 0 then return end
  local request = pending[role]
  pending[role] = nil
  local terminals = require("config.terminals")
  if current then
    for _, job in ipairs(current.jobs) do terminals.dispose(job.term) end
  end

  local state = { jobs = {}, running = 0, request = request }
  active[role], last_phase = state, role
  local commands = request.phase == "build" and { request.config.build } or run_commands(request.config.run)
  for index, command in ipairs(commands) do
    local job = { running = true }
    state.jobs[#state.jobs + 1] = job
    state.running = state.running + 1
    local label = request.phase == "run" and #commands > 1 and "run " .. index or request.phase
    local ok, err = pcall(function()
      job.term = terminals.create({
        cmd = command,
        dir = request.cwd,
        direction = "horizontal",
        panel_kind = "output",
        panel_role = request.phase,
        display_name = label == "build" and "Build" or (label == "run" and "Run" or label:gsub("^run", "Run")),
        close_on_exit = false,
        on_exit = function(_, _, code)
          if not job.running then return end
          job.running = false
          state.running = state.running - 1
          -- ToggleTerm finishes its TermClose handling before a replacement starts.
          vim.schedule(function()
            if quitting or active[role] ~= state then return end
            if not state.cancelled then
              if code ~= 0 then
                notify(label .. " exited with code " .. code, vim.log.levels.ERROR)
              elseif request.phase == "build" then
                notify("Build succeeded")
                if request.run_after then
                  pending.run = vim.tbl_extend("force", request, { phase = "run", run_after = false })
                end
              end
            end
            pump()
          end)
        end,
      })
      terminals.show(job.term, { focus = false, tab = request.tab })
    end)
    if not ok or not job.term.job_id or job.term.job_id <= 0 then
      if job.running then
        job.running = false
        state.running = state.running - 1
      end
      stop_state(state)
      notify("Could not start " .. label .. ": " .. tostring(err or "terminal did not start"), vim.log.levels.ERROR)
      break
    end
  end
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
    if action == "build_run" then
      pending = {}
      stop_current()
    else
      stop_state(active[phase])
      if action == "run" and active.build then active.build.request.run_after = false end
    end
    pending[phase] = {
      root = root, config = settings, cwd = cwd, window = window, tab = api.nvim_get_current_tabpage(),
      phase = phase, run_after = action == "build_run" and phase == "build",
    }
    pump()
  end
  local needs_config = (action == "build" and config.build == "")
    or (action ~= "build" and #run_commands(config.run) == 0)
  if needs_config then configure(root, start) else start(config) end
end

function M.terminal()
  local current = active[last_phase]
  return current and current.jobs[1] and current.jobs[1].term
end

function M.terminals()
  local result = {}
  for _, role in ipairs({ "build", "run" }) do
    for _, job in ipairs(active[role] and active[role].jobs or {}) do
      if job.term then result[#result + 1] = job.term end
    end
  end
  return result
end

function M.reserves(id)
  return vim.iter(M.terminals()):any(function(term) return term.id == id end)
end

function M.toggle()
  local output = vim.tbl_filter(function(term)
    return term.bufnr and api.nvim_buf_is_valid(term.bufnr)
  end, M.terminals())
  if #output > 0 then
    local latest = M.terminal()
    require("config.terminals").show(vim.tbl_contains(output, latest) and latest or output[1])
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
    { "po", M.toggle, "Show project output" },
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
