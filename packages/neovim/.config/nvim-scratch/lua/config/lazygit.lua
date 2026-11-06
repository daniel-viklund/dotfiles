local M = {}
local api = vim.api
local sessions = {}
local last_repo = {}
local window, repos, selected, current_workspace

local function notify(message)
  vim.notify(message, vim.log.levels.ERROR, { title = "LazyGit" })
end

local function visible()
  return window and api.nvim_win_is_valid(window)
end

local function close()
  if visible() then
    api.nvim_win_close(window, true)
  end
  window = nil
end

local function layout()
  local width = math.max(1, math.floor(vim.o.columns * 0.9))
  local height = math.max(1, math.floor((vim.o.lines - vim.o.cmdheight - 2) * 0.9))
  return {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.floor((vim.o.columns - width) / 2),
  }
end

local function title()
  return (" %s [%d/%d] | Alt+[/] repos "):format(vim.fs.basename(repos[selected]), selected, #repos)
end

local function show(index)
  local root = repos[index]
  local session = sessions[root]
  if session and not api.nvim_buf_is_valid(session.buf) then
    session = nil
  end
  if session and session.exited then
    api.nvim_buf_delete(session.buf, { force = true })
    session = nil
  end
  local fresh = not session
  if fresh then
    session = { buf = api.nvim_create_buf(false, true) }
    sessions[root] = session
    vim.bo[session.buf].bufhidden = "hide"
    vim.bo[session.buf].swapfile = false
    for key, direction in pairs({ ["<M-[>"] = -1, ["<M-]>"] = 1 }) do
      vim.keymap.set({ "n", "t" }, key, function() M.cycle(direction) end, {
        buffer = session.buf,
        desc = direction == 1 and "Next Git repo" or "Previous Git repo",
      })
    end
  end
  selected = index
  if visible() then
    api.nvim_set_current_win(window)
    api.nvim_win_set_buf(window, session.buf)
    api.nvim_win_set_config(window, { title = title(), title_pos = "center" })
  else
    window = api.nvim_open_win(session.buf, true, vim.tbl_extend("force", layout(), {
      style = "minimal",
      border = "rounded",
      title = title(),
      title_pos = "center",
    }))
  end
  if fresh then
    session.job = vim.fn.jobstart({ "lazygit" }, {
      term = true,
      cwd = root,
      on_exit = function(_, code)
        vim.schedule(function()
          session.exited = true
          if code ~= 0 then
            notify(("Exited with code %d in %s"):format(code, root))
            return
          end
          if visible() and api.nvim_win_get_buf(window) == session.buf then
            close()
          end
          if api.nvim_buf_is_valid(session.buf) then
            api.nvim_buf_delete(session.buf, { force = true })
          end
          if sessions[root] == session then
            sessions[root] = nil
          end
          vim.cmd.checktime()
        end)
      end,
    })
    if session.job <= 0 then
      notify("Could not start LazyGit in " .. root)
      close()
      api.nvim_buf_delete(session.buf, { force = true })
      sessions[root] = nil
      return
    end
  end
  last_repo[current_workspace] = root
  vim.cmd.startinsert()
end

function M.cycle(direction)
  if visible() then
    show((selected - 1 + direction) % #repos + 1)
  end
end

function M.open()
  if vim.fn.executable("lazygit") ~= 1 then
    notify("lazygit is not installed or is not on PATH")
    return
  end
  local cwd = vim.fn.getcwd()
  local path = vim.bo.buftype == "" and api.nvim_buf_get_name(0) or cwd
  if path == "" then path = cwd end
  local root = vim.fs.root(path, ".git")
  if not root then
    notify("No Git repository found for " .. path)
    return
  end
  local workspace = vim.fs.root(cwd, ".git") or root
  if root ~= workspace and root:sub(1, #workspace + 1) ~= workspace .. "/" then
    workspace = root
  end
  local scan, err = vim.uv.fs_scandir(workspace)
  if not scan then
    notify("Cannot scan workspace: " .. tostring(err))
    return
  end
  local children = {}
  while true do
    local name = vim.uv.fs_scandir_next(scan)
    if not name then break end
    if name ~= ".git" then
      local child = vim.fs.joinpath(workspace, name)
      local marker = vim.uv.fs_stat(vim.fs.joinpath(child, ".git"))
      if marker and (marker.type == "directory" or marker.type == "file") then
        children[#children + 1] = child
      end
    end
  end
  table.sort(children)
  repos = { workspace }
  vim.list_extend(repos, children)
  if not vim.tbl_contains(repos, root) then
    repos[#repos + 1] = root
  end
  current_workspace = workspace
  local remembered = vim.fn.index(repos, last_repo[workspace] or "")
  show(remembered >= 0 and remembered + 1 or vim.fn.index(repos, root) + 1)
end

api.nvim_create_autocmd("VimResized", {
  group = api.nvim_create_augroup("WorkspaceLazyGit", { clear = true }),
  callback = function()
    if visible() then
      api.nvim_win_set_config(window, layout())
    end
  end,
})

return M
