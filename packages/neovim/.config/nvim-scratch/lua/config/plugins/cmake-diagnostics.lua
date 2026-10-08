-- Publish compiler output from an existing CMake build as searchable diagnostics.
local running = false
local last_output = { "No CMake diagnostic build has run yet." }
local remembered_dir

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "CMake diagnostics" })
end

local function default_dir()
  if remembered_dir then return remembered_dir end
  local cwd = vim.fn.getcwd()
  if vim.fn.filereadable(vim.fs.joinpath(cwd, "CMakeCache.txt")) == 1 then return cwd end
  return vim.fs.joinpath(cwd, "build")
end

local function build(directory, clean)
  if running then
    notify("A diagnostic build is already running.", vim.log.levels.WARN)
    return
  end
  directory = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(directory), ":p"))
  if vim.fn.filereadable(vim.fs.joinpath(directory, "CMakeCache.txt")) == 0 then
    notify("Choose a configured CMake build directory containing CMakeCache.txt.", vim.log.levels.ERROR)
    return
  end
  if vim.fn.executable("cmake") == 0 then
    notify("cmake is not on PATH.", vim.log.levels.ERROR)
    return
  end

  local command = { "cmake", "--build", directory }
  if clean then command[#command + 1] = "--clean-first" end
  local errorformat = "%D__CMAKE_BUILD_DIR__%f," .. vim.o.errorformat
  local lines = { "__CMAKE_BUILD_DIR__" .. directory }
  local streams = { stdout = "", stderr = "" }
  local function collect(stream)
    return function(err, data)
      if err then data = tostring(err) .. "\n" end
      if not data then return end
      streams[stream] = streams[stream] .. data
      while true do
        local ending = streams[stream]:find("\n", 1, true)
        if not ending then break end
        lines[#lines + 1] = streams[stream]:sub(1, ending - 1):gsub("\r$", "")
        streams[stream] = streams[stream]:sub(ending + 1)
      end
    end
  end

  running = true
  remembered_dir = directory
  notify((clean and "Clean rebuild: " or "Building: ") .. directory)
  local ok, failure = pcall(vim.system, command, {
    cwd = directory,
    env = { NO_COLOR = "1", CLICOLOR = "0" },
    stdout = collect("stdout"),
    stderr = collect("stderr"),
  }, vim.schedule_wrap(function(result)
    running = false
    for _, stream in ipairs({ "stdout", "stderr" }) do
      if streams[stream] ~= "" then lines[#lines + 1] = streams[stream] end
    end
    for index, line in ipairs(lines) do
      lines[index] = line:gsub("\27%[[0-9;]*m", "")
    end
    last_output = vim.list_slice(lines, 2)
    local items = vim.fn.getqflist({ lines = lines, efm = errorformat }).items
    local namespace = vim.api.nvim_create_namespace("cmake-build:" .. directory)
    local by_buffer, count = {}, 0
    for _, item in ipairs(items) do
      if item.valid == 1 and item.bufnr > 0 and item.lnum > 0 then
        local severity = vim.diagnostic.severity.ERROR
        if item.type:lower() == "w" or item.text:match("^%s*warning[: ]") then
          severity = vim.diagnostic.severity.WARN
        elseif item.type:lower() == "n" or item.text:match("^%s*note[: ]") then
          severity = vim.diagnostic.severity.INFO
        end
        by_buffer[item.bufnr] = by_buffer[item.bufnr] or {}
        table.insert(by_buffer[item.bufnr], {
          lnum = item.lnum - 1,
          col = math.max(item.col - 1, 0),
          message = item.text,
          severity = severity,
          source = "CMake build",
        })
        count = count + 1
      end
    end
    -- This namespace represents this build's output, independently of clangd.
    vim.diagnostic.reset(namespace)
    for buffer, diagnostics in pairs(by_buffer) do
      vim.diagnostic.set(namespace, buffer, diagnostics)
    end
    notify(("Build exited %d; %d diagnostics. Space sD to search; :CMakeDiagnosticsLog for output.")
      :format(result.code, count), result.code == 0 and vim.log.levels.INFO or vim.log.levels.WARN)
  end))
  if not ok then
    running = false
    notify(tostring(failure), vim.log.levels.ERROR)
  end
end

vim.api.nvim_create_user_command("CMakeDiagnostics", function(opts)
  build(opts.args ~= "" and opts.args or default_dir(), opts.bang)
end, { nargs = "?", bang = true, complete = "dir", desc = "Build CMake diagnostics (! cleans first)" })

vim.api.nvim_create_user_command("CMakeDiagnosticsLog", function()
  vim.cmd("botright new")
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_lines(0, 0, -1, false, last_output)
  vim.bo.modifiable = false
end, { desc = "Show the latest CMake diagnostic build output" })

vim.keymap.set("n", "<leader>sc", function()
  vim.ui.input({ prompt = "CMake build directory: ", default = default_dir(), completion = "dir" }, function(value)
    if value and vim.trim(value) ~= "" then build(value, false) end
  end)
end, { desc = "Build CMake diagnostics" })
