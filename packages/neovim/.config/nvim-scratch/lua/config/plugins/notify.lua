vim.pack.add({
  "https://github.com/rcarriga/nvim-notify",
})

local notify = require("notify")

-- Compact layout without the built-in renderer's vertical separator.
local function render_compact(buf, notification, highlights)
  local namespace = require("notify.render.base").namespace()
  local icon = notification.icon
  local title = notification.title[1]
  if type(title) == "string" and notification.duplicates then
    title = string.format("%s x%d", title, #notification.duplicates)
  end
  local icon_prefix = icon ~= "" and icon .. " " or ""
  local prefix = icon_prefix .. (type(title) == "string" and title ~= "" and title .. ": " or "")
  local lines = { prefix .. notification.message[1], unpack(notification.message, 2) }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_extmark(buf, namespace, 0, 0, {
    hl_group = highlights.icon,
    end_col = #icon,
    priority = 50,
  })
  vim.api.nvim_buf_set_extmark(buf, namespace, 0, #icon_prefix, {
    hl_group = highlights.title,
    end_col = #prefix,
    priority = 50,
  })
  vim.api.nvim_buf_set_extmark(buf, namespace, 0, #prefix, {
    hl_group = highlights.body,
    end_line = #lines,
    priority = 50,
  })
end

local function match_editor_background()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  for _, level in ipairs({ "ERROR", "WARN", "INFO", "DEBUG", "TRACE" }) do
    for _, part in ipairs({ "Body", "Border", "Icon", "Title" }) do
      local name = "Notify" .. level .. part
      local highlight = vim.api.nvim_get_hl(0, { name = name, link = false })
      highlight.bg = normal.bg or "NONE"
      vim.api.nvim_set_hl(0, name, highlight)
    end
  end
end

match_editor_background()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("NotifyEditorBackground", { clear = true }),
  callback = match_editor_background,
})

notify.setup({
  background_colour = "Normal",
  timeout = 2500,
  stages = "static",
  render = render_compact,
  -- Use text symbols instead of the default Nerd Font icons.
  icons = {
    ERROR = "✖",
    WARN = "▲",
    INFO = "ℹ",
    DEBUG = "◆",
    TRACE = "·",
  },
  minimum_width = 15,
  max_width = function()
    return math.min(42, math.max(15, math.floor(vim.o.columns * 0.3)))
  end,
  -- Keep popups brief; Noice history retains the full message.
  max_height = 2,
  on_open = function(win)
    vim.api.nvim_win_set_config(win, { border = "rounded" })
  end,
  top_down = true,
})

vim.notify = notify

vim.api.nvim_create_user_command("NotifyDemo", function(args)
  local examples = {
    info = { "Your changes were saved.", vim.log.levels.INFO },
    warn = { "Connection is slow.", vim.log.levels.WARN },
    error = { "Could not save the file.", vim.log.levels.ERROR },
  }
  local kinds = args.args == "" and { "info", "warn", "error" } or { args.args }
  if not examples[kinds[1]] then
    vim.notify("Use :NotifyDemo [info|warn|error]", vim.log.levels.WARN)
    return
  end
  for _, kind in ipairs(kinds) do
    local example = examples[kind]
    vim.notify(example[1], example[2], { title = "Demo", timeout = 5000 })
  end
end, {
  nargs = "?",
  desc = "Preview notification styles (sample messages)",
  complete = function()
    return { "info", "warn", "error" }
  end,
})

vim.keymap.set("n", "<leader>nh", "<cmd>Noice history<CR>", { desc = "Message history" })
vim.keymap.set("n", "<leader>nd", function()
  notify.dismiss({ silent = true, pending = true })
end, { desc = "Dismiss notifications" })
