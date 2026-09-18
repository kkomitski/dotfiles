local wezterm = require 'wezterm'

local config = wezterm.config_builder()
config.automatically_reload_config = true
config.default_prog = { 'tmux', 'new-session', '-A', '-s', 'main' }

-- JetBrains Mono Nerd Font supplies the prompt glyphs and keeps code readable.
config.font = wezterm.font_with_fallback({
  'JetBrainsMonoNL Nerd Font',
  'Apple Color Emoji',
})
config.font_size = 13.0
config.line_height = 1.08
config.cell_width = 1.0

-- Soft Catppuccin-inspired palette: lower contrast without washing out syntax.
config.colors = {
  foreground = '#cdd6f4',
  background = '#1e1e2e',
  cursor_bg = '#f5e0dc',
  cursor_fg = '#1e1e2e',
  cursor_border = '#f5e0dc',
  selection_bg = '#45475a',
  selection_fg = '#f5e0dc',
  split = '#45475a',
  ansi = {
    '#45475a', -- black
    '#f38ba8', -- red
    '#a6e3a1', -- green
    '#f9e2af', -- yellow
    '#89b4fa', -- blue
    '#f5c2e7', -- magenta
    '#94e2d5', -- cyan
    '#bac2de', -- white
  },
  brights = {
    '#585b70', -- black
    '#f38ba8', -- red
    '#a6e3a1', -- green
    '#f9e2af', -- yellow
    '#89b4fa', -- blue
    '#f5c2e7', -- magenta
    '#94e2d5', -- cyan
    '#a6adc8', -- white
  },
  tab_bar = {
    background = '#181825',
    active_tab = {
      bg_color = '#313244',
      fg_color = '#cdd6f4',
      intensity = 'Bold',
    },
    inactive_tab = {
      bg_color = '#181825',
      fg_color = '#7f849c',
    },
    inactive_tab_hover = {
      bg_color = '#313244',
      fg_color = '#cdd6f4',
    },
    new_tab = {
      bg_color = '#181825',
      fg_color = '#7f849c',
    },
    new_tab_hover = {
      bg_color = '#313244',
      fg_color = '#cdd6f4',
    },
  },
}

config.window_background_opacity = 0.94
config.macos_window_background_blur = 18
config.window_padding = {
  left = 16,
  right = 16,
  top = 12,
  bottom = 10,
}

config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.inactive_pane_hsb = {
  saturation = 0.85,
  brightness = 0.72,
}
config.default_cursor_style = 'BlinkingBar'
config.cursor_blink_rate = 650
config.scrollback_lines = 10000
config.audible_bell = 'Disabled'
config.warn_about_missing_glyphs = false



config.keys = {
  { key = 'c', mods = 'CMD', action = wezterm.action.CopyTo 'Clipboard' },
  { key = 'v', mods = 'CMD', action = wezterm.action.PasteFrom 'Clipboard' },
  { key = 't', mods = 'CMD', action = wezterm.action.SendString('\002') },
  { key = 'b', mods = 'CMD', action = wezterm.action.SendString('\002b') },
  { key = 'p', mods = 'CMD', action = wezterm.action.SendKey { key = 'p', mods = 'CTRL' } },
  { key = 'P', mods = 'CMD', action = wezterm.action.SendKey { key = 'p', mods = 'CTRL|SHIFT' } },
  { key = 'w', mods = 'CMD', action = wezterm.action.SendString('\002x') },
}

for index = 1, 5 do
  table.insert(config.keys, {
    key = tostring(index),
    mods = 'CMD',
    action = wezterm.action.SendString('\002' .. tostring(index)),
  })
end

return config
