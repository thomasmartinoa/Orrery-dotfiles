#!/usr/bin/env python3
"""
Static checks for the rice: everything that can be verified without a
running desktop. GitHub runs this on every push and pull request
(.github/workflows/ci.yml); run it yourself before you push:

    tests/check.py            skips a check whose tool isn't installed
    tests/check.py --strict   a missing tool is a failure (CI)
    tests/check.py --theme DIR [--theme DIR…]   check only these theme folders
                              (a generated one: tests/install-test.sh)

Checks: shell scripts parse and pass shellcheck's error level; QML parses;
qmldir entries exist; Hyprland's Lua parses; JSON files and menu.jsonc parse;
every icon name the shell and the menu use is in the icon set; every shipped
theme renders, its output is complete and valid, its text is readable on its
background and it has a wallpaper; install.sh and uninstall.sh agree on the
stow packages; no personal paths are committed.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STRICT = "--strict" in sys.argv
EXTRA_THEMES = [Path(sys.argv[i + 1]).expanduser().resolve() for i, a in enumerate(sys.argv[:-1]) if a == "--theme"]
QS = ROOT / "quickshell/.config/quickshell"
ORRERY = ROOT / "theme/.config/orrery"

failures, skipped = [], []


def fail(check, msg):
    failures.append(f"{check}: {msg}")


def tool(*names):
    for n in names:
        p = shutil.which(n) or (n if os.path.isfile(n) and os.access(n, os.X_OK) else None)
        if p:
            return p
    return None


def need(check, path):
    if path:
        return True
    (fail if STRICT else lambda c, m: skipped.append(f"{c}: {m}"))(check, "tool not installed")
    return False


def tracked():
    out = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-z"], capture_output=True, text=True, check=True).stdout
    return [ROOT / p for p in out.split("\0") if p]


def is_text(p):
    try:
        return b"\0" not in p.read_bytes()[:4096]
    except OSError:
        return False


# --theme: only those themes (the other checks then have no files to look at)
FILES = [] if EXTRA_THEMES else [p for p in tracked() if p.is_file()]


def shebang(p):
    try:
        with open(p, "rb") as f:
            return f.readline().decode("utf-8", "replace")
    except OSError:
        return ""


# ---------------------------------------------------------------- scripts --
scripts = [p for p in FILES if re.match(r"#!.*\b(ba)?sh\b", shebang(p)) or p.suffix == ".sh"]
for p in scripts:
    r = subprocess.run(["bash", "-n", str(p)], capture_output=True, text=True)
    if r.returncode:
        fail("bash -n", f"{p.relative_to(ROOT)}: {r.stderr.strip()}")

for p in [f for f in FILES if re.match(r"#!.*\bpython3?\b", shebang(f)) or f.suffix == ".py"]:
    r = subprocess.run([sys.executable, "-c", "import ast,sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])", str(p)],
                       capture_output=True, text=True)
    if r.returncode:
        fail("python syntax", f"{p.relative_to(ROOT)}: {(r.stderr.strip().splitlines() or ['?'])[-1]}")

sc = tool("shellcheck")
if scripts and need("shellcheck", sc):
    r = subprocess.run([sc, "-S", "error", "-f", "gcc", *map(str, scripts)], capture_output=True, text=True)
    for line in r.stdout.splitlines():
        fail("shellcheck", line.replace(str(ROOT) + "/", ""))

# -------------------------------------------------------------------- QML --
# Qt 6's: /usr/bin/qmlformat may be Qt 5's, which rejects valid Qt 6 syntax (": void")
qmlformat = tool("/usr/lib/qt6/bin/qmlformat", "qmlformat6", "qmlformat")
if FILES and need("qml syntax", qmlformat):
    for p in [f for f in FILES if f.suffix == ".qml"]:
        r = subprocess.run([qmlformat, str(p)], capture_output=True, text=True)
        if r.returncode:
            err = ((r.stderr + r.stdout).strip().splitlines() or ["does not parse"])[0]
            fail("qml syntax", f"{p.relative_to(ROOT)}: {err}")

for qmldir in [f for f in FILES if f.name == "qmldir"]:
    for line in qmldir.read_text().splitlines():
        parts = line.split()
        # "Type 1.0 File.qml" / "singleton Type 1.0 File.qml"
        if parts and parts[-1].endswith((".qml", ".js")) and not (qmldir.parent / parts[-1]).is_file():
            fail("qmldir", f"{qmldir.relative_to(ROOT)}: {parts[-1]} does not exist")

# -------------------------------------------------------------------- Lua --
luac = tool("luac", "luac5.4")
if FILES and need("lua syntax", luac):
    for p in [f for f in FILES if f.suffix == ".lua"]:
        r = subprocess.run([luac, "-p", str(p)], capture_output=True, text=True)
        if r.returncode:
            fail("lua syntax", r.stderr.strip().replace(str(ROOT) + "/", ""))

# ------------------------------------------------------------------- JSON --
for p in [f for f in FILES if f.suffix == ".json"]:
    try:
        json.loads(p.read_text())
    except ValueError as e:
        fail("json", f"{p.relative_to(ROOT)}: {e}")


def jsonc(text):
    # what Services/Menu.qml does: whole-line // comments are dropped
    return json.loads("\n".join(l for l in text.splitlines() if not re.match(r"\s*//", l)))


menu = {}
try:
    menu = jsonc((ORRERY / "menu.jsonc").read_text())
except (OSError, ValueError) as e:
    fail("menu.jsonc", str(e))
for mid in menu:
    parent = mid.rsplit(".", 1)[0] if "." in mid else None
    if parent and parent not in menu:
        fail("menu.jsonc", f'"{mid}" has no parent entry "{parent}"')

# ------------------------------------------------------------------ icons --
icons = set(re.findall(r'"([a-z0-9_]+)":\[', (QS / "Commons/IconPaths.js").read_text()))
listed = {l.strip() for l in (QS / "Commons/icons/names.txt").read_text().splitlines() if l.strip() and not l.startswith("#")}
for n in sorted(listed - icons):
    fail("icons", f'"{n}" is in names.txt but not in IconPaths.js: run Commons/icons/build.py')
used = {}
for mid, e in menu.items():
    if isinstance(e, dict) and isinstance(e.get("icon"), str):
        used.setdefault(e["icon"], f"menu.jsonc {mid}")
for p in [f for f in FILES if f.suffix == ".qml" and QS in f.parents]:
    for m in re.finditer(r'\bicon\s*:\s*"([^"]*)"', p.read_text()):
        # a component with its own picture set (Power/icons/<name>-rest.png) isn't a Material Symbol
        if list(p.parent.glob(f"icons/{m.group(1)}-*.png")):
            continue
        used.setdefault(m.group(1), str(p.relative_to(ROOT)))
for name, where in sorted(used.items()):
    # a plain name is a Material Symbol (Commons/Icon.qml); anything else is a glyph
    if re.fullmatch(r"[a-z0-9_]+", name) and name not in icons:
        fail("icons", f'"{name}" ({where}) is not in Commons/icons/names.txt: add it and run build.py')

# ----------------------------------------------------------------- themes --
def lum(h):
    h = h.lstrip("#")
    def ch(c):
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    hi, lo = sorted((lum(a), lum(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


# the targets in skills/orrery/theming.md
CONTRAST = {"fg": 12, "accent_mid": 4.5, "accent_dim": 3}
themes = sorted({f.parent for f in FILES if f.name == "colors.toml" and f.parent.parent == ORRERY / "themes"}) + EXTRA_THEMES
if not themes:
    fail("themes", "no shipped theme found")
for t in themes:
    tid = t.name
    try:
        conf = tomllib.loads((t / "colors.toml").read_text())
    except (OSError, ValueError) as e:
        fail("themes", f"{tid}: colors.toml: {e}")
        continue
    if conf.get("mode") not in ("dark", "light"):
        fail("themes", f'{tid}: mode must be "dark" or "light"')
    if conf.get("bar", "minimal") not in ("minimal", "floating", "pill"):
        fail("themes", f"{tid}: bar must be minimal, floating or pill")
    if conf.get("dock", "") not in ("", "bottom", "left", "right", "top", "off"):
        fail("themes", f"{tid}: dock must be bottom, left, right, top or off")
    if not (isinstance(conf.get("radius", 4), int) and 0 <= conf.get("radius", 4) <= 24):
        fail("themes", f"{tid}: radius must be a whole number 0-24")
    c = conf.get("colors", {})
    for key, target in CONTRAST.items():
        if key in c and "bg0" in c:
            ratio = contrast(c[key], c["bg0"])
            if ratio < target:
                fail("themes", f"{tid}: {key} on bg0 is {ratio:.1f}:1, needs {target}:1")
    bgs = [b for b in (t / "backgrounds").glob("*") if b.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp")] if (t / "backgrounds").is_dir() else []
    # a generated (Wallpaper) theme's picture can live anywhere
    if not bgs and "GENERATED by orrery-wall-theme" not in (t / "colors.toml").read_text():
        fail("themes", f"{tid}: no wallpaper in backgrounds/")
    with tempfile.TemporaryDirectory() as out:
        r = subprocess.run([sys.executable, str(ORRERY / "render.py"), str(t), str(ORRERY / "templates"), out],
                           capture_output=True, text=True)
        if r.returncode:
            fail("themes", f"{tid}: render.py failed: {(r.stderr.strip().splitlines() or ['?'])[-1]}")
            continue
        rendered = sorted(Path(out).iterdir())
        expected = {p.name[:-4] for p in (ORRERY / "templates").glob("*.tpl")}
        missing = expected - {p.name for p in rendered}
        if missing:
            fail("themes", f"{tid}: not rendered: {', '.join(sorted(missing))}")
        for p in rendered:
            text = p.read_text(errors="replace")
            if "{{" in text or "}}" in text:
                line = next(l for l in text.splitlines() if "{{" in l or "}}" in l)
                fail("themes", f"{tid}: {p.name} has an unrendered tag: {line.strip()[:80]}")
            if p.suffix == ".json":
                try:
                    json.loads(text)
                except ValueError as e:
                    fail("themes", f"{tid}: {p.name} is not valid JSON: {e}")

# ---------------------------------------------------- install / uninstall --
def bash_array(script, name):
    m = re.search(rf"^{name}=\(([^)]*)\)", (ROOT / script).read_text(), re.M)
    return m.group(1).split() if m else None


for name in ("PACKAGES", "RETIRED_PACKAGES"):
    a, b = bash_array("install.sh", name), bash_array("uninstall.sh", name)
    if a is None:
        fail("install", f"install.sh has no {name}=(…)")
    elif a != b:
        fail("install", f"{name} differs: install.sh {a} vs uninstall.sh {b}")
for pkg in bash_array("install.sh", "PACKAGES") or []:
    if not (ROOT / pkg).is_dir():
        fail("install", f'stow package "{pkg}" is listed in install.sh but not in the repo')

# ---------------------------------------------------------------- privacy --
personal = re.compile(r"/home/(?!<|\$|user\b|you\b|tester\b)[a-z_][a-z0-9_-]*/")   # tester: the CI user
for p in FILES:
    if p.suffix in (".md",) or not is_text(p):
        continue
    for i, line in enumerate(p.read_text(errors="replace").splitlines(), 1):
        if personal.search(line):
            fail("privacy", f"{p.relative_to(ROOT)}:{i}: a home path: {line.strip()[:80]}")

# ----------------------------------------------------------------- report --
for s in skipped:
    print(f"skip  {s}")
for f in failures:
    print(f"FAIL  {f}")
print(f"\n{len(failures)} problem(s), {len(skipped)} check(s) skipped, "
      f"{len(scripts)} scripts, {len([f for f in FILES if f.suffix == '.qml'])} QML files, {len(themes)} themes")
sys.exit(1 if failures else 0)
