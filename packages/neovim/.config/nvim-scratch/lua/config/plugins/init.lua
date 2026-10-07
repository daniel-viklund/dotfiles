-- Each file installs and configures its own plugins.
local directory = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))
local modules = {}

for name, kind in vim.fs.dir(directory) do
  if kind == "file" and name:sub(-4) == ".lua" and name ~= "init.lua" then
    modules[#modules + 1] = name:sub(1, -5)
  end
end

-- Keep startup order predictable (including LSP settings before Mason).
table.sort(modules)
for _, name in ipairs(modules) do
  require("config.plugins." .. name)
end
