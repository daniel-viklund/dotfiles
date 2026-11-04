-- ~/.config/wezterm/wezterm.lua   (Linux/macOS)
-- ~/.wezterm.lua                   (any OS, in your home dir)
--
-- WezTerm has NO default config file on disk — it applies built-in defaults
-- and you override them here. Every value below is set to (or near) WezTerm's
-- own default, so you can uncomment / change things and immediately see the
-- effect. Save the file and WezTerm hot-reloads automatically.
--
-- Full reference: https://wezfurlong.org/wezterm/config/lua/config/index.html

local wezterm = require 'wezterm'

wezterm.add_to_config_reload_watch_list(wezterm.config_dir)

local tab_mod = wezterm.target_triple:find('windows') and 'ALT' or 'SUPER'

-- The config_builder gives you clearer error messages if you mistype a key.
local config = wezterm.config_builder()

--------------------------------------------------------------------------------
-- FONT
--------------------------------------------------------------------------------
-- Default is a bundled build of JetBrains Mono. You can name any installed font.
config.font = wezterm.font 'MesloLGS NF'
-- Fallback chain: if a glyph is missing in the first font, the next is tried.
-- config.font = wezterm.font_with_fallback {
--   'JetBrains Mono',
--   'Fira Code',
--   'Noto Color Emoji',
-- }

-- You can request weights/styles and per-font options:
-- config.font = wezterm.font('JetBrains Mono', { weight = 'Bold', italic = false })

config.font_size = 16.0            -- default 12.0 (macOS default is often perceived larger due to DPI)
config.line_height = 1          -- multiplier; 1.1–1.2 gives more breathing room
config.cell_width = 1           -- horizontal cell scaling
-- config.freetype_load_target = 'Normal'   -- 'Normal' | 'Light' | 'Mono' | 'HorizontalLcd'
-- config.freetype_render_target = 'Normal'
-- config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' }  -- ligatures on (default). Disable with =0.
config.warn_about_missing_glyphs = true

--------------------------------------------------------------------------------
-- COLORS / THEME
--------------------------------------------------------------------------------
-- Use a built-in scheme (hundreds available). Browse: https://wezfurlong.org/wezterm/colorschemes/
-- Gruvbox dark (medium contrast), matching Neovim, tmux, and Powerlevel10k.
config.colors = {
  foreground = '#ebdbb2',
  background = '#282828',
  cursor_bg = '#ebdbb2',
  cursor_fg = '#282828',
  cursor_border = '#ebdbb2',
  selection_bg = '#504945',
  selection_fg = '#ebdbb2',
  split = '#665c54',
  ansi = { '#282828', '#cc241d', '#98971a', '#d79921', '#458588', '#b16286', '#689d6a', '#a89984' },
  brights = { '#928374', '#fb4934', '#b8bb26', '#fabd2f', '#83a598', '#d3869b', '#8ec07c', '#ebdbb2' },
}

-- ...or define colors by hand. This overrides parts of the scheme above.
-- config.colors = {
--   foreground = '#cccccc',
--   background = '#000000',
--   cursor_bg = '#52ad70',
--   cursor_fg = '#000000',
--   cursor_border = '#52ad70',
--   selection_fg = 'black',
--   selection_bg = '#fffacd',
--   scrollbar_thumb = '#222222',
--   split = '#444444',
--   ansi   = { '#000', '#800000', '#008000', '#808000', '#000080', '#800080', '#008080', '#c0c0c0' },
--   brights = { '#808080', '#f00', '#0f0', '#ff0', '#00f', '#f0f', '#0ff', '#fff' },
-- }

--------------------------------------------------------------------------------
-- WINDOW
--------------------------------------------------------------------------------
-- 'TITLE | RESIZE' is the default. Try 'RESIZE' for a borderless look,
-- or 'NONE' for no decorations at all.
config.window_decorations = "RESIZE"

-- Fully opaque terminal
config.window_background_opacity = 1.0

config.macos_window_background_blur = 0

config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}

config.initial_cols = 80           -- starting window size in cells
config.initial_rows = 24
config.adjust_window_size_when_changing_font_size = true
-- Prefer whole terminal cells when resizing to avoid a partial-row gap.
config.use_resize_increments = false

-- Confirm before closing a window that still has running processes.
config.window_close_confirmation = 'AlwaysPrompt'   -- 'AlwaysPrompt' | 'NeverPrompt'

--------------------------------------------------------------------------------
-- TAB BAR
--------------------------------------------------------------------------------
config.enable_tab_bar = false
config.use_fancy_tab_bar = false            -- false = retro/terminal-style tab bar
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = false
config.show_tab_index_in_tab_bar = true
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 16

--------------------------------------------------------------------------------
-- CURSOR
--------------------------------------------------------------------------------
config.default_cursor_style = 'SteadyBlock'   -- Steady/Blinking + Block/Underline/Bar
config.cursor_blink_rate = 0                 -- ms; 0 disables blinking
config.cursor_blink_ease_in = 'Linear'
config.cursor_blink_ease_out = 'Linear'
config.force_reverse_video_cursor = false

--------------------------------------------------------------------------------
-- SCROLLBACK & SCROLLBAR
--------------------------------------------------------------------------------
config.scrollback_lines = 3500     -- default 3500; raise for more history (uses more RAM)
config.enable_scroll_bar = false

--------------------------------------------------------------------------------
-- BELL
--------------------------------------------------------------------------------
config.audible_bell = 'SystemBeep'   -- 'SystemBeep' | 'Disabled'
-- config.visual_bell = {
--   fade_in_function = 'EaseIn',
--   fade_in_duration_ms = 75,
--   fade_out_function = 'EaseOut',
--   fade_out_duration_ms = 75,
-- }

--------------------------------------------------------------------------------
-- PANES
--------------------------------------------------------------------------------
-- Dim inactive panes so you can tell which one is focused.
config.inactive_pane_hsb = {
  saturation = 0.9,
  brightness = 0.8,
}

--------------------------------------------------------------------------------
-- SHELL / PROGRAM
--------------------------------------------------------------------------------
-- By default WezTerm launches your login shell. Override if you like:
-- config.default_prog = { 'bash', '-l' }
if wezterm.target_triple:find('windows') then
  config.default_prog = { 'wsl.exe', '-d', 'Ubuntu-24.04', '--cd', '~' }
end
-- config.default_cwd = wezterm.home_dir

-- On Windows, choose the default shell WezTerm spawns:
-- config.default_domain = 'WSL:Ubuntu'

--------------------------------------------------------------------------------
-- PERFORMANCE
--------------------------------------------------------------------------------
config.front_end = 'WebGpu'        -- 'WebGpu' (GPU, modern default) | 'OpenGL' | 'Software'
config.max_fps = 60
config.animation_fps = 60

--------------------------------------------------------------------------------
-- KEY BINDINGS
--------------------------------------------------------------------------------
-- These ADD to (and can override) the built-in defaults. See defaults at:
-- https://wezfurlong.org/wezterm/config/default-keys.html
config.keys = {
  -- Send Option/Alt+Enter for CLI multiline input, including through tmux.
  -- A pasted newline can be swallowed by the CLI's paste handling.
  {
    key = 'Enter', mods = 'SHIFT',
    action = wezterm.action.SendString '\x1b\r',
  },

  -- Split panes
  { key = '"', mods = 'CTRL|SHIFT|ALT', action = wezterm.action.SplitVertical   { domain = 'CurrentPaneDomain' } },
  { key = '%', mods = 'CTRL|SHIFT|ALT', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },

  -- Move between panes
  { key = 'LeftArrow',  mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Left'  },
  { key = 'RightArrow', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Right' },
  { key = 'UpArrow',    mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Up'    },
  { key = 'DownArrow',  mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Down'  },

  -- Font size
  { key = '=', mods = 'CTRL', action = wezterm.action.IncreaseFontSize },
  { key = '-', mods = 'CTRL', action = wezterm.action.DecreaseFontSize },
  { key = '0', mods = 'CTRL', action = wezterm.action.ResetFontSize },

  -- Copy mode & clipboard
  { key = 'x', mods = 'CTRL|SHIFT', action = wezterm.action.ActivateCopyMode },
  { key = 'c', mods = 'CTRL|SHIFT', action = wezterm.action.CopyTo 'Clipboard' },
  { key = 'v', mods = 'CTRL|SHIFT', action = wezterm.action.PasteFrom 'Clipboard' },

  -- Tabs
  { key = 't', mods = tab_mod, action = wezterm.action.SpawnTab 'CurrentPaneDomain' },
  { key = 'w', mods = tab_mod, action = wezterm.action.CloseCurrentTab { confirm = true } },

  -- Send tmux's Ctrl+a prefix followed by a command (Cmd on Mac, Alt on Windows).
  { key = 'x', mods = tab_mod, action = wezterm.action.SendString '\x01x' },
  { key = 'c', mods = tab_mod, action = wezterm.action.SendString '\x01c' },
  { key = 's', mods = tab_mod, action = wezterm.action.SendString '\x01s' },
  { key = '[', mods = tab_mod, action = wezterm.action.SendString '\x01[' },

  -- Select tmux windows by sending Ctrl+a followed by the window number.
  { key = '1', mods = tab_mod, action = wezterm.action.SendString '\x011' },
  { key = '2', mods = tab_mod, action = wezterm.action.SendString '\x012' },
  { key = '3', mods = tab_mod, action = wezterm.action.SendString '\x013' },
  { key = '4', mods = tab_mod, action = wezterm.action.SendString '\x014' },
  { key = '5', mods = tab_mod, action = wezterm.action.SendString '\x015' },
  { key = '6', mods = tab_mod, action = wezterm.action.SendString '\x016' },
  { key = '7', mods = tab_mod, action = wezterm.action.SendString '\x017' },
  { key = '8', mods = tab_mod, action = wezterm.action.SendString '\x018' },
  { key = '9', mods = tab_mod, action = wezterm.action.SendString '\x019' },
}

-- To wipe ALL default keybindings and start clean, uncomment:
-- config.disable_default_key_bindings = true

-- Leader key example (tmux-style prefix). Uncomment to enable:
-- config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }

--------------------------------------------------------------------------------
-- MOUSE BINDINGS
--------------------------------------------------------------------------------
-- config.mouse_bindings = {
--   -- Ctrl-click opens the hovered hyperlink
--   {
--     event = { Up = { streak = 1, button = 'Left' } },
--     mods = 'CTRL',
--     action = wezterm.action.OpenLinkAtMouseCursor,
--   },
-- }

--------------------------------------------------------------------------------
-- MISC
--------------------------------------------------------------------------------
config.automatically_reload_config = true
config.check_for_updates = true
config.term = 'xterm-256color'      -- set to 'wezterm' if you install its terminfo

return config
