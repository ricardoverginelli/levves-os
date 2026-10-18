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
    "dialogs/background.svgz",
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


def main():
    shutil.rmtree(OUT, ignore_errors=True)
    OUT.mkdir(parents=True)
    shutil.copy(HERE / "metadata.json", OUT)
    shutil.copy(SYSTEM / "breeze-dark/plasmarc", OUT)
    build_colors()
    build_glass()
    print(f"Built {OUT}")


main()
