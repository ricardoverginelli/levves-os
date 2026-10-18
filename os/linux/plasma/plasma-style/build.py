#!/usr/bin/env python3
"""Build the "Leaves" Plasma style from ../palette.json into ~/.local/share/plasma/desktoptheme/leaves.

Starts from the Breeze Dark style installed on this machine (so it tracks Plasma
updates), swaps in the palette, and makes translucent panels and popups more see-through
(glass: the fill lets KWin's blur show through).
Everything not overridden falls back to the stock "default" style.
"""
import configparser
import gzip
import json
import re
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
SYSTEM = Path("/usr/share/plasma/desktoptheme")
OUT = Path.home() / ".local/share/plasma/desktoptheme/leaves"

palette = json.loads((HERE.parent / "palette.json").read_text())


def rgb(name):
    h = palette[name].lstrip("#")
    return ",".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4))


# Background per color set; foregrounds/decorations are shared
BACKGROUNDS = {
    "Window": ("bg", "surface"),
    "View": ("bg-deep", "bg"),
    "Button": ("raised", "surface"),
    "Header": ("surface", "bg"),
    "Header][Inactive": ("bg", "bg-deep"),
    "Tooltip": ("surface", "raised"),
    "Complementary": ("bg-deep", "bg"),
    "Selection": ("accent", "accent-pressed"),
}
FOREGROUNDS = {
    "ForegroundNormal": "text",
    "ForegroundInactive": "text-muted",
    "ForegroundActive": "accent",
    "ForegroundLink": "accent",
    "ForegroundVisited": "accent-pressed",
    "ForegroundNegative": "critical",
    "ForegroundNeutral": "warning",
    "ForegroundPositive": "success",
    "DecorationFocus": "accent",
    "DecorationHover": "accent-hover",
}


def build_colors():
    colors = configparser.ConfigParser(interpolation=None, strict=False)
    colors.optionxform = str  # keep key case
    colors.read(SYSTEM / "breeze-dark/colors")
    for color_set, (normal, alternate) in BACKGROUNDS.items():
        section = f"Colors:{color_set}"
        if not colors.has_section(section):
            colors.add_section(section)
        colors[section]["BackgroundNormal"] = rgb(normal)
        colors[section]["BackgroundAlternate"] = rgb(alternate)
        for key, role in FOREGROUNDS.items():
            colors[section][key] = rgb(role)
        if color_set == "Selection":
            colors[section]["ForegroundNormal"] = rgb("on-accent")
    with open(OUT / "colors", "w") as f:
        colors.write(f, space_around_delimiters=False)


# Translucent backgrounds (used while KWin blur is on). Breeze draws their
# fill at 0.85; glass uses the palette's glass-opacity.
GLASS = [
    "widgets/panel-background.svgz",
    "widgets/tooltip.svgz",
]


def build_glass():
    for path in GLASS:
        src = SYSTEM / "default/translucent" / path
        svg = gzip.decompress(src.read_bytes()).decode()
        svg = re.sub(r"opacity:0\.85\b", f"opacity:{palette['glass-opacity']}", svg)
        dest = OUT / "translucent" / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(gzip.compress(svg.encode(), mtime=0))  # reproducible, so apply.sh can spot changes


SVG_NS = "http://www.w3.org/2000/svg"
FRAME = ["topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom", "bottomright"]
HINTS = ["hint-top-margin", "hint-bottom-margin", "hint-left-margin", "hint-right-margin",
         "hint-top-inset", "hint-bottom-inset", "hint-left-inset", "hint-right-inset"]


def frame_svg(r, fill_attrs, prefix="", ox=0, oy=0):
    """The 9 frame pieces of a box with corner radius r, laid out from (ox, oy):
    corners are r×r quarter circles, edges are r thick, the center is 32×32."""
    c = 32
    quarter = {  # quarter-circle corner, filled toward the box's inside
        "topleft": f"M0,{r} A{r},{r} 0 0 1 {r},0 V{r} Z",
        "topright": f"M0,0 A{r},{r} 0 0 1 {r},{r} H0 Z",
        "bottomleft": f"M0,0 H{r} V{r} A{r},{r} 0 0 1 0,0 Z",
        "bottomright": f"M0,0 H{r} A{r},{r} 0 0 1 0,{r} Z",
    }
    cells = {  # name: (x, y, w, h) inside a 3×3 grid
        "topleft": (0, 0, r, r), "top": (r, 0, c, r), "topright": (r + c, 0, r, r),
        "left": (0, r, r, c), "center": (r, r, c, c), "right": (r + c, r, r, c),
        "bottomleft": (0, r + c, r, r), "bottom": (r, r + c, c, r), "bottomright": (r + c, r + c, r, r),
    }
    out = []
    for name in FRAME:
        x, y, w, h = cells[name]
        shape = (f'<path d="{quarter[name]}" {fill_attrs}/>' if name in quarter
                 else f'<rect width="{w}" height="{h}" {fill_attrs}/>')
        out.append(f'<g id="{prefix}{name}" transform="translate({ox + x},{oy + y})">{shape}</g>')
    return "".join(out)


def build_dialog_background():
    """Popups: glass fill with the DESIGN.md large radius. Breeze's corners are
    ~6px, so the frame and its blur mask are redrawn; Breeze's shadow is kept."""
    src = SYSTEM / "default/translucent/dialogs/background.svgz"
    ET.register_namespace("", SVG_NS)
    root = ET.fromstring(gzip.decompress(src.read_bytes()))

    # Drop Breeze's frame, blur mask and margin hints (shadow-* pieces stay)
    drop = set(FRAME) | {f"mask-{n}" for n in FRAME} | set(HINTS)
    for parent in root.iter():
        for child in list(parent):
            if child.get("id") in drop:
                parent.remove(child)

    r = palette["popup-radius"]
    margin = 4  # content padding inside the frame, as in Breeze
    oy = 80  # below Breeze's shadow pieces
    size = r * 2 + 32
    fill = f'class="ColorScheme-Background" style="fill:currentColor;opacity:{palette['glass-opacity']}"'
    extra = frame_svg(r, fill, ox=0, oy=oy)
    extra += frame_svg(r, 'style="fill:#000000"', prefix="mask-", ox=size + 8, oy=oy)
    # Hints: margin rects set the content padding; zero-size insets as in Breeze
    extra += (f'<rect id="hint-top-margin" x="0" y="{oy + size + 8}" width="{margin}" height="{margin}"/>'
              f'<rect id="hint-bottom-margin" x="8" y="{oy + size + 8}" width="{margin}" height="{margin}"/>'
              f'<rect id="hint-left-margin" x="16" y="{oy + size + 8}" width="{margin}" height="{margin}"/>'
              f'<rect id="hint-right-margin" x="24" y="{oy + size + 8}" width="{margin}" height="{margin}"/>')
    for el in ET.fromstring(f'<g xmlns="{SVG_NS}">{extra}</g>'):
        root.append(el)

    width = max(float(root.get("width")), (size + 8) * 2)
    height = oy + size + 8 + margin
    root.set("width", str(width))
    root.set("height", str(height))
    root.set("viewBox", f"0 0 {width} {height}")

    dest = OUT / "translucent/dialogs/background.svgz"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(gzip.compress(ET.tostring(root), mtime=0))


def main():
    shutil.rmtree(OUT, ignore_errors=True)
    OUT.mkdir(parents=True)
    shutil.copy(HERE / "metadata.json", OUT)
    shutil.copy(SYSTEM / "breeze-dark/plasmarc", OUT)
    build_colors()
    build_glass()
    build_dialog_background()
    print(f"Built {OUT}")


main()
