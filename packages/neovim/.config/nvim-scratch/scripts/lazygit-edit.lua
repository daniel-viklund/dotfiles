local path = vim.fn.fnamemodify(assert(arg[1], "Missing file argument"), ":p")
local function first_change(staged)
  local command = {
    "git", "--literal-pathspecs", "diff", "--no-ext-diff", "--no-textconv", "--no-color", "--unified=0",
  }
  if staged then command[#command + 1] = "--cached" end
  vim.list_extend(command, { "--", path })
  local result = vim.system(command, { text = true }):wait()
  assert(result.code == 0, "Cannot locate first change: " .. result.stderr)
  for hunk in result.stdout:gmatch("[^\n]+") do
    local row, count = hunk:match("^@@ %-%d+,?%d* %+(%d+),?(%d*) @@")
    if row then
      -- Deletion-only hunks point to the line before the removed section.
      return tonumber(row) + (count == "0" and 1 or 0)
    end
  end
end

local line
if arg[2] then
  line = assert(tonumber(arg[2]), "Invalid line number")
  assert(line == math.floor(line), "Line number must be an integer")
else
  line = first_change(false) or first_change(true) or 1
end
local server = assert(vim.env.NVIM, "Missing parent Neovim server")
local channel = vim.fn.sockconnect("pipe", server, { rpc = true })
assert(channel > 0, "Cannot connect to parent Neovim")
local opened = vim.rpcrequest(channel, "nvim_exec_lua",
  'return require("config.lazygit").edit_file(...)', { path, line })
assert(opened, "Parent Neovim could not open " .. path)
vim.cmd.qa()
