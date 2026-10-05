#!/usr/bin/env python3
"""The README cover and the GitHub social preview, from one design: the
wordmark with orbits and the four shipped themes' real previews
(themes/<id>/preview.jpg, from orrery-theme-preview).

    Screenshots/cover.png    README header, rounded card
    Screenshots/social.png   1280x640 repo social preview (Settings > Social
                             preview); everything inside GitHub's 40pt border
    Screenshots/themes.webp  the README's theme tour: each desktop with its
                             name, crossfading to the next, looping

Rerun after retaking a preview:
    python3 Screenshots/make-cover.py        (needs rsvg-convert, ffmpeg, python-pillow, Inter, JetBrains Mono)"""
import math, os, random, shutil, subprocess, sys, tempfile

OUT = os.path.dirname(os.path.abspath(__file__))
THEMES = os.path.join(OUT, "..", "theme", ".config", "orrery", "themes")
BG, BG2 = "#09090c", "#14141a"
FG, MUTED = "#ededf0", "#9a9aa4"
TILT = -9

# one line under each name in the theme tour
BLURB = {
    "eclipse": "dark · greys only",
    "zenith": "the same design on white",
    "catppuccin-mocha": "the official Mocha palette",
    "cassini": "ringed giant · ice-teal on deep space",
}

# (id, label, planet colour, planet radius, orbit index, angle on orbit in deg)
SHOTS = [
    ("eclipse",          "Eclipse",          "#e8e8e8", 9,  0, 200),
    ("zenith",           "Zenith",           "#f4f4f4", 13, 1, 332),
    ("catppuccin-mocha", "Catppuccin Mocha", "#b4befe", 11, 1, 158),
    ("cassini",          "Cassini",          "#9fd8ce", 15, 2, 18),
]

# every size is in design units; `k` scales the wordmark block, the rest is layout
LAYOUTS = {
    "cover": dict(W=2400, H=1110, width=2000, radius=32, cy=330, k=1.0,
                  margin=110, gap=36, py=650, labels=True, glow=28, stars=0.58),
    # 2x of GitHub's 1280x640; its "40pt border" is 80px there, 160 units here
    "social": dict(W=2560, H=1280, width=1280, radius=0, cy=390, k=1.18,
                   margin=210, gap=40, py=790, labels=False, glow=30, stars=0.58),
}


def build(name, L, tmp):
    W, H, cy, k = L["W"], L["H"], L["cy"], L["k"]
    cx = W / 2
    orbits = [(560 * k, 118 * k, 0.30), (820 * k, 178 * k, 0.20), (1080 * k, 238 * k, 0.12)]

    def on_orbit(i, deg):
        rx, ry, _ = orbits[i]
        t = math.radians(deg)
        x, y = rx * math.cos(t), ry * math.sin(t)
        a = math.radians(TILT)
        return cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)

    out = []
    add = out.append
    add(f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'width="{W}" height="{H}" viewBox="0 0 {W} {H}">')
    add(f'''<defs>
  <radialGradient id="glow" cx="50%" cy="{L['glow']}%" r="60%">
    <stop offset="0" stop-color="{BG2}"/><stop offset="1" stop-color="{BG}"/>
  </radialGradient>
  <radialGradient id="sun" cx="50%" cy="50%" r="50%">
    <stop offset="0" stop-color="#ffffff" stop-opacity="0.10"/>
    <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
  </radialGradient>
  <filter id="soft" x="-200%" y="-200%" width="500%" height="500%">
    <feGaussianBlur stdDeviation="7"/>
  </filter>
  <filter id="feather"><feGaussianBlur stdDeviation="14"/></filter>
  <mask id="quiet" maskUnits="userSpaceOnUse" x="0" y="0" width="{W}" height="{H}">
    <rect width="{W}" height="{H}" fill="#fff"/>
  </mask>
  <clipPath id="card"><rect width="{W}" height="{H}" rx="{L['radius']}"/></clipPath>
</defs>''')
    add('<g clip-path="url(#card)">')
    add(f'<rect width="{W}" height="{H}" fill="url(#glow)"/>')

    # stars: fixed seed, faint, none behind the wordmark
    rnd = random.Random(7)
    for _ in range(int(230 * W * H / (2400 * 1110))):
        x, y = rnd.uniform(0, W), rnd.uniform(0, H * L["stars"])
        if abs(x - cx) < 560 * k and abs(y - cy) < 110 * k:
            continue
        r = rnd.choice([0.8, 0.8, 1.0, 1.2, 1.6])
        add(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="#ffffff" opacity="{rnd.uniform(0.12, 0.5):.2f}"/>')

    # a soft light where the sun would be, then the orbits
    add(f'<ellipse cx="{cx}" cy="{cy}" rx="{700 * k}" ry="{260 * k}" fill="url(#sun)"/>')
    add('<g mask="url(#quiet)">')
    for rx, ry, op in orbits:
        add(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="none" stroke="#ffffff" '
            f'stroke-opacity="{op}" stroke-width="{1.6 * k:.2f}" transform="rotate({TILT} {cx} {cy})"/>')
    add('</g>')

    # the wordmark
    add(f'<text x="{cx}" y="{cy + 64 * k}" text-anchor="middle" font-family="Inter Display" font-weight="200" '
        f'font-size="{184 * k}" letter-spacing="{58 * k}" fill="{FG}">ORRERY</text>')

    # planets: one per theme, drawn over the orbits and the text
    for tid, label, col, r, oi, deg in SHOTS:
        x, y = on_orbit(oi, deg)
        r *= k
        add(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r * 1.8}" fill="{col}" opacity="0.35" filter="url(#soft)"/>')
        add(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="{col}"/>')
        if tid == "cassini":   # a ringed giant gets its ring
            add(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{r * 2.1}" ry="{r * 0.55}" fill="none" '
                f'stroke="{col}" stroke-opacity="0.8" stroke-width="2" transform="rotate(-18 {x:.1f} {y:.1f})"/>')

    # the four real previews
    M, GAP, py = L["margin"], L["gap"], L["py"]
    pw = (W - 2 * M - 3 * GAP) / 4
    ph = pw * 900 / 1600
    for i, (tid, label, col, r, oi, deg) in enumerate(SHOTS):
        shutil.copy(f"{THEMES}/{tid}/preview.jpg", f"{tmp}/{tid}.jpg")
        px = M + i * (pw + GAP)
        add(f'<clipPath id="c{i}"><rect x="{px:.1f}" y="{py}" width="{pw:.1f}" height="{ph:.1f}" rx="14"/></clipPath>')
        add(f'<rect x="{px - 1:.1f}" y="{py - 1}" width="{pw + 2:.1f}" height="{ph + 2:.1f}" rx="15" fill="#000" opacity="0.6" filter="url(#soft)"/>')
        add(f'<image x="{px:.1f}" y="{py}" width="{pw:.1f}" height="{ph:.1f}" xlink:href="{tid}.jpg" '
            f'preserveAspectRatio="xMidYMid slice" clip-path="url(#c{i})"/>')
        add(f'<rect x="{px:.1f}" y="{py}" width="{pw:.1f}" height="{ph:.1f}" rx="14" fill="none" stroke="#ffffff" stroke-opacity="0.14" stroke-width="1.5"/>')
        if L["labels"]:
            ly = py + ph + 62
            tw = len(label) * 15.2 + (len(label) - 1) * 4.2     # rough text width, for the dot
            lx = px + pw / 2
            add(f'<circle cx="{lx - tw / 2 - 22:.1f}" cy="{ly - 9}" r="7" fill="{col}"/>')
            add(f'<text x="{lx:.1f}" y="{ly}" text-anchor="middle" font-family="JetBrainsMono Nerd Font" font-weight="400" '
                f'font-size="25" letter-spacing="4" fill="{MUTED}">{label.upper()}</text>')

    add('</g></svg>')
    svg = f"{tmp}/{name}.svg"
    with open(svg, "w") as fh:
        fh.write("\n".join(out))
    subprocess.run(["rsvg-convert", "-w", str(L["width"]), "-o", f"{OUT}/{name}.png", svg], check=True)
    print(f"{OUT}/{name}.png")


def tour(tmp, hold=2.4, fade=0.6, fps=24, width=1600):
    """themes.webp: every preview with a name tag, crossfading in a loop."""
    desks, tags = [], []
    for tid, label, col, *_ in SHOTS:
        shutil.copy(f"{THEMES}/{tid}/preview.jpg", f"{tmp}/{tid}.jpg")
        desks.append(f"{tmp}/{tid}.jpg")
        # the tag, on its own transparent layer: a dark chip in the
        # bottom-left corner, clear of the dock
        w = 68 + max(len(label) * 15.5, len(BLURB[tid]) * 9.7)
        svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900">
  <rect x="40" y="788" width="{w:.0f}" height="82" rx="10" fill="#0a0a0c" fill-opacity="0.78"
        stroke="#ffffff" stroke-opacity="0.16" stroke-width="1.5"/>
  <circle cx="70" cy="818" r="7" fill="{col}"/>
  <text x="88" y="828" font-family="Inter" font-weight="600" font-size="27" fill="#ededf0">{label}</text>
  <text x="88" y="856" font-family="Inter" font-weight="400" font-size="19" fill="#a4a4ae">{BLURB[tid]}</text>
</svg>"""
        with open(f"{tmp}/tag-{tid}.svg", "w") as fh:
            fh.write(svg)
        subprocess.run(["rsvg-convert", "-w", str(width), "-o", f"{tmp}/tag-{tid}.png", f"{tmp}/tag-{tid}.svg"], check=True)
        tags.append(f"{tmp}/tag-{tid}.png")
    desks.append(desks[0])                   # fade back into the first: a seamless loop
    tags.append(tags[0])
    n, step = len(SHOTS), hold + fade
    total = n * step                         # theme k is still from k*step to k*step + hold

    # the desktops crossfade into each other
    args, chain, last = [], [], "0:v"
    for f in desks:
        args += ["-loop", "1", "-t", str(hold + 2 * fade), "-framerate", str(fps), "-i", f]
    for i in range(1, len(desks)):
        chain.append(f"[{last}][{i}:v]xfade=transition=fade:duration={fade}:offset={i * hold + (i - 1) * fade:.2f},scale={width}:-2[x{i}]")
        last = f"x{i}"
    # the tags don't overlap: the old one fades out in the first half of a
    # crossfade, the new one fades in during the second half
    for k, f in enumerate(tags):
        idx = len(desks) + k
        args += ["-loop", "1", "-t", f"{total:.2f}", "-framerate", str(fps), "-i", f]
        fx = ["format=rgba"]
        if k > 0:
            fx.append(f"fade=t=in:st={k * step - fade / 2:.2f}:d={fade / 2:.2f}:alpha=1")
        if k < n:
            fx.append(f"fade=t=out:st={k * step + hold:.2f}:d={fade / 2:.2f}:alpha=1")
        chain.append(f"[{idx}:v]{','.join(fx)}[t{k}]")
        chain.append(f"[{last}][t{k}]overlay=format=auto[o{k}]")
        last = f"o{k}"
    # end where the loop begins again, so it doesn't stall on the repeat
    chain.append(f"[{last}]trim=duration={total:.2f}[v]")
    os.makedirs(f"{tmp}/fr")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", *args, "-filter_complex", ";".join(chain),
                    "-map", "[v]", "-pix_fmt", "rgb24", f"{tmp}/fr/%04d.png"], check=True)
    # Encode with Pillow, every frame a keyframe. ffmpeg's encoder stores most
    # frames as lossy patches over the one before, and over a fade the errors
    # pile up: dark wallpapers came out blocky with the previous theme's colours.
    try:
        from PIL import Image, ImageChops
    except ImportError:
        sys.exit("themes.webp needs Pillow: sudo pacman -S python-pillow")
    shots, durs = [], []
    for f in sorted(os.listdir(f"{tmp}/fr")):
        im = Image.open(f"{tmp}/fr/{f}").convert("RGB")
        if shots and ImageChops.difference(im, shots[-1]).getbbox() is None:
            durs[-1] += 1000 / fps           # a still: one frame, shown longer
        else:
            shots.append(im)
            durs.append(1000 / fps)
    shots[0].save(f"{OUT}/themes.webp", save_all=True, append_images=shots[1:],
                  duration=[round(d) for d in durs], loop=0, quality=88, method=4, kmin=0, kmax=1)
    print(f"{OUT}/themes.webp")


tmp = tempfile.mkdtemp()       # the SVGs and the copies they link to
try:
    for name, L in LAYOUTS.items():
        build(name, L, tmp)
    tour(tmp)
finally:
    shutil.rmtree(tmp)
