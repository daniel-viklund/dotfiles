-- Shared by the platform installers; run with nvim --headless -u NONE -S.
local function main()
  assert(vim.fn.has("nvim-0.12") == 1, "Neovim 0.12 or newer is required")
  local uv = vim.uv
  local source = assert(uv.fs_realpath(vim.env.NVIM_CONFIG_SOURCE), "Invalid NVIM_CONFIG_SOURCE")
  local target = vim.fs.normalize(vim.fn.stdpath("config"))

  local function log(message)
    io.stdout:write(message .. "\n")
    io.stdout:flush()
  end

  for _, name in ipairs({ "git", "tree-sitter", "rg", "lazygit", "curl", "tar", "cargo", "rustup" }) do
    assert(vim.fn.executable(name) == 1, "Missing executable: " .. name)
  end
  for name, minimum in pairs({ ["tree-sitter"] = { 0, 26, 1 } }) do
    local result = vim.system({ name, "--version" }, { text = true }):wait()
    local version = vim.version.parse(result.stdout or "")
    assert(result.code == 0 and version and vim.version.ge(version, minimum), name .. " is too old")
  end

  local function copy(from, to)
    local stat = assert(uv.fs_stat(from))
    if stat.type == "directory" then
      vim.fn.mkdir(to, "p")
      for name in vim.fs.dir(from) do
        copy(vim.fs.joinpath(from, name), vim.fs.joinpath(to, name))
      end
    else
      assert(uv.fs_copyfile(from, to))
    end
  end

  -- Stage the copy before touching an existing installation.
  if uv.fs_realpath(target) ~= source then
    local normalized_source = vim.fs.normalize(source)
    assert(not vim.startswith(normalized_source, target .. "/"), "Source is inside destination; choose another app name")
    assert(not vim.startswith(target, normalized_source .. "/"), "Destination is inside source; choose another app name")
    local staging = target .. ".install-" .. uv.os_getpid()
    assert(not uv.fs_lstat(staging), "Staging directory already exists: " .. staging)
    vim.fn.mkdir(staging, "p")
    for _, name in ipairs({ "init.lua", "lua", "nvim-pack-lock.json", "scripts", "readme.md", ".gitignore" }) do
      copy(vim.fs.joinpath(source, name), vim.fs.joinpath(staging, name))
    end
    local backup
    if uv.fs_lstat(target) then
      backup = target .. ".backup-" .. os.date("%Y%m%d-%H%M%S") .. "-" .. uv.os_getpid()
      assert(uv.fs_rename(target, backup))
      log("Previous config saved to " .. backup)
    end
    local moved, err = uv.fs_rename(staging, target)
    if not moved then
      if backup then assert(uv.fs_rename(backup, target)) end
      error(err)
    end
  end

  -- Persist only the archive-tool paths inside this Neovim installation.
  if vim.env.NVIM_INSTALL_EXTRA_PATHS and vim.env.NVIM_INSTALL_EXTRA_PATHS ~= "" then
    vim.fn.writefile({ vim.env.NVIM_INSTALL_EXTRA_PATHS }, vim.fs.joinpath(target, "windows-path.txt"))
  end
  vim.opt.runtimepath:prepend(target)
  log("Installing plugins into " .. vim.fn.stdpath("data"))
  local pack_add = vim.pack.add
  vim.pack.add = function(specs, opts)
    return pack_add(specs, vim.tbl_extend("force", opts or {}, { confirm = false, load = true }))
  end
  dofile(vim.fs.joinpath(target, "init.lua"))
  vim.pack.add = pack_add

  log("Waiting for Tree-sitter parsers...")
  assert(require("config.plugins.treesitter"):wait(600000), "Some parsers failed to install; check the compiler and output above")
  log("Installing configured language servers through Mason...")
  -- mason-lspconfig skips automatic installation in headless sessions.
  local registry = require("mason-registry")
  registry.refresh()
  local mappings = require("mason-lspconfig").get_mappings().lspconfig_to_package
  local Package = require("mason-core.package")
  local packages = {}
  for _, identifier in ipairs(require("config.plugins.mason").ensure_installed) do
    local server, version = Package.Parse(identifier)
    local name = assert(mappings[server], "No Mason package mapping for " .. server)
    packages[#packages + 1] = name .. (version and "@" .. version or "")
  end
  -- Quiet mode avoids treating archive progress written to stderr as an Ex error.
  if #packages > 0 then
    require("mason.api.command").MasonInstall(packages, { quiet = true })
  end
  for _, identifier in ipairs(packages) do
    local name = Package.Parse(identifier)
    assert(registry.get_package(name):is_installed(), "Mason could not install " .. name)
  end
  assert(vim.fn.exists(":LazyGit") == 2, "LazyGit command was not registered")
  log("Config, plugins, parsers, and language servers are ready: " .. target)
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
  io.stderr:write("Installation failed:\n" .. err .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
