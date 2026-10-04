#!/usr/bin/env python3
"""
orrery-theme template renderer.

    render.py <theme-dir> <templates-dir> <out-dir>

Reads <theme-dir>/colors.toml, renders every <templates-dir>/*.tpl into
<out-dir>/<name> (the .tpl suffix dropped).

Template syntax — one tag per colour, Omarchy-style:

    {{ bg0 }}                    #0a0a0a
    {{ bg0 | strip }}            0a0a0a
    {{ bg0 | upper }}            #0A0A0A
    {{ bg0 | rgb }}              10, 10, 10
    {{ bg0 | kde }}              10,10,10
    {{ bg0 | rgba 0.6 }}         rgba(10, 10, 10, 0.6)
    {{ bg0 | hex8 0.6 }}         #0a0a0a99        (translucent)
    {{ bg0 | argb }}             #ff0a0a0a        (qt6ct)
    {{ bg0 | argb 0.1 }}         #190a0a0a
    {{ bg0 | hypr }}             rgba(0a0a0aff)   (hyprland)
    {{ bg0 | hypr 0.66 }}        rgba(0a0a0aa8)
    {{ mix bg0 fg 20% }}         a colour 20% of the way from bg0 to fg
    {{ dark "1" "0" }}           first value if mode = dark, else second
    {{ hued }}                   true / false (the flag itself; JSON-friendly)
    {{ hued blue grey1 }}        first value if the theme sets hued = true, else second
                                 (only the chosen side is resolved, so a hued theme may
                                 define extra hue keys and use them there)
    {{ mode }} {{ name }} {{ bar }}   plain strings from the top level
    {{ home }}                   $HOME, for absolute url() paths in CSS
    {{ gtk_theme }}              anything under [apps] / [terminal] / [colors]
    {{ added }} {{ modified }}   [git] hues (the only real colours in the rice)

Filters chain: {{ mix bg0 fg 20% | hypr 0.5 }}.
"""

import os
import re
import sys
import tomllib
from pathlib import Path

TAG = re.compile(r"\{\{\s*(.*?)\s*\}\}")


def hex_to_rgb(h):
    h = h.lstrip("#")
    if len(h) != 6:
        raise ValueError(f"not a #rrggbb colour: {h!r}")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgb_to_hex(r, g, b):
    return "#%02x%02x%02x" % (round(r), round(g), round(b))


def parse_amount(s):
    s = s.strip()
    if s.endswith("%"):
        return float(s[:-1]) / 100
    v = float(s)
    return v / 100 if v > 1 else v


def alpha_byte(a):
    return round(max(0.0, min(1.0, float(a))) * 255)


class Renderer:
    def __init__(self, theme):
        self.vars = {}
        # layout a theme may suggest; the user's own choice (menu, shell.json,
        # orrery-border) wins over it
        self.vars.update({"bar": "minimal", "radius": "4", "dock": ""})
        for k in ("name", "mode", "bar", "radius", "dock"):
            if k in theme:
                self.vars[k] = str(theme[k])
        self.hued = bool(theme.get("hued", False))
        self.vars["hued"] = "true" if self.hued else "false"
        self.vars["home"] = os.environ.get("HOME", "")
        for section in ("colors", "terminal", "apps", "git"):
            for k, v in theme.get(section, {}).items():
                self.vars[k] = str(v)
        self.mode = self.vars.get("mode", "dark")

    # ----- expressions -----
    def value(self, tok):
        if tok.startswith('"') and tok.endswith('"'):
            return tok[1:-1]
        if tok in self.vars:
            return self.vars[tok]
        if tok.startswith("#"):
            return tok
        raise KeyError(f"unknown name {tok!r}")

    def expr(self, text):
        parts = text.split()
        if not parts:
            raise ValueError("empty tag")
        head = parts[0]
        if head == "mix":
            a, b, amt = parts[1], parts[2], parts[3]
            ra, rb = hex_to_rgb(self.value(a)), hex_to_rgb(self.value(b))
            t = parse_amount(amt)
            return rgb_to_hex(*(x * (1 - t) + y * t for x, y in zip(ra, rb)))
        if head == "dark":
            toks = re.findall(r'"[^"]*"|\S+', text)[1:]
            return self.value(toks[0]) if self.mode == "dark" else self.value(toks[1])
        if head == "light":
            toks = re.findall(r'"[^"]*"|\S+', text)[1:]
            return self.value(toks[0]) if self.mode == "light" else self.value(toks[1])
        if head == "hued" and len(parts) > 1:
            toks = re.findall(r'"[^"]*"|\S+', text)[1:]
            return self.value(toks[0]) if self.hued else self.value(toks[1])
        if len(parts) != 1:
            raise ValueError(f"bad expression {text!r}")
        return self.value(head)

    # ----- filters -----
    def apply_filter(self, val, name, args):
        if name == "strip":
            return val.lstrip("#")
        if name == "upper":
            return val.upper()
        if name == "lower":
            return val.lower()
        r, g, b = hex_to_rgb(val)
        if name == "rgb":
            return f"{r}, {g}, {b}"
        if name == "kde":
            return f"{r},{g},{b}"
        if name == "rgba":
            a = args[0] if args else "1"
            return f"rgba({r}, {g}, {b}, {a})"
        if name == "hex8":
            a = alpha_byte(args[0]) if args else 255
            return "#%02x%02x%02x%02x" % (r, g, b, a)
        if name == "argb":
            a = alpha_byte(args[0]) if args else 255
            return "#%02x%02x%02x%02x" % (a, r, g, b)
        if name == "hypr":
            a = alpha_byte(args[0]) if args else 255
            return "rgba(%02x%02x%02x%02x)" % (r, g, b, a)
        raise ValueError(f"unknown filter {name!r}")

    def tag(self, body):
        chunks = [c.strip() for c in body.split("|")]
        val = self.expr(chunks[0])
        for f in chunks[1:]:
            fparts = f.split()
            val = self.apply_filter(val, fparts[0], fparts[1:])
        return val

    def render(self, text, where):
        def sub(m):
            try:
                return self.tag(m.group(1))
            except Exception as e:  # noqa: BLE001
                raise SystemExit(f"{where}: in {{{{ {m.group(1)} }}}}: {e}")
        return TAG.sub(sub, text)


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    theme_dir, tpl_dir, out_dir = (Path(p) for p in sys.argv[1:])
    with open(theme_dir / "colors.toml", "rb") as fh:
        theme = tomllib.load(fh)
    r = Renderer(theme)
    out_dir.mkdir(parents=True, exist_ok=True)
    n = 0
    for tpl in sorted(tpl_dir.glob("*.tpl")):
        out = out_dir / tpl.name[:-4]
        out.write_text(r.render(tpl.read_text(), tpl.name))
        n += 1
    print(f"rendered {n} files -> {out_dir}")


if __name__ == "__main__":
    main()
