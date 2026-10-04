{
  "name": "{{ name }}",
  "mode": "{{ mode }}",
  "hued": {{ hued }},
  "bar": "{{ bar }}",
  "colors": {
    "bg0": "{{ bg0 }}", "bg1": "{{ bg1 }}", "bg2": "{{ bg2 }}", "bg3": "{{ bg3 }}", "bg4": "{{ bg4 }}",
    "fg": "{{ fg }}",
    "accentBright": "{{ accent_bright }}", "accentLight": "{{ accent_light }}",
    "accentMid": "{{ accent_mid }}", "accentDim": "{{ accent_dim }}",
    "active": "{{ active }}", "hover": "{{ hover }}", "warning": "{{ warning }}", "critical": "{{ critical }}",
    "good": "{{ green }}",
    "grey0": "{{ grey0 }}", "grey1": "{{ grey1 }}", "grey2": "{{ grey2 }}",
    "border": "{{ accent_light | argb 0.24 }}", "borderStrong": "{{ accent_bright | argb 0.67 }}"
  },
  "radius": {{ radius }},
  "dock": "{{ dock }}",
  "terminal": {
    "background": "{{ background }}", "foreground": "{{ foreground }}", "cursor": "{{ cursor }}",
    "color0": "{{ color0 }}", "color1": "{{ color1 }}", "color2": "{{ color2 }}", "color3": "{{ color3 }}",
    "color4": "{{ color4 }}", "color5": "{{ color5 }}", "color6": "{{ color6 }}", "color7": "{{ color7 }}",
    "color8": "{{ color8 }}", "color9": "{{ color9 }}", "color10": "{{ color10 }}", "color11": "{{ color11 }}",
    "color12": "{{ color12 }}", "color13": "{{ color13 }}", "color14": "{{ color14 }}", "color15": "{{ color15 }}"
  },
  "apps": {
    "gtkTheme": "{{ gtk_theme }}", "iconTheme": "{{ icon_theme }}", "cursorTheme": "{{ cursor_theme }}",
    "qtStyle": "{{ qt_style }}", "nvimColorscheme": "{{ nvim_colorscheme }}"
  }
}
