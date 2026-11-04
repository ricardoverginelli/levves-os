#!/usr/bin/env python3
"""Build the "Leaves" Plasma style from the Levves tokens into ~/.local/share/plasma/desktoptheme/leaves.

Starts from the Breeze Dark style installed on this machine (so it tracks Plasma updates), swaps
in the Levves colors and redraws the frames of panels, popups and tooltips as D draws containers
(design/DESIGN.md): opaque, a 1px near-black edge with an engraved inner line, 2px corners. No glass.
Everything not overridden falls back to the stock "default" style.
"""
import configparser
import gzip
import importlib.util
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
SYSTEM = Path("/usr/share/plasma/desktoptheme")
OUT = Path.home() / ".local/share/plasma/desktoptheme/leaves"

_spec = importlib.util.spec_from_file_location("levves_tokens", HERE.parents[3] / "design/dist/levves_tokens.py")
_tokens = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_tokens)
TOKENS = _tokens.TOKENS


def color(name):
    return TOKENS[f"color.{name}"]


def rgb(name):
    h = color(name).lstrip("#")
    return ",".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4))


# Background per color set; foregrounds/decorations are shared
BACKGROUNDS = {
    "Window": ("surface", "bg"),            # popups are windows in D
    "View": ("well", "bg"),                 # lists and fields sit in a well
    "Button": ("raised", "surface"),        # keys
    "Header": ("title-bar", "surface"),     # popup headings
    "Header][Inactive": ("title-bar-inactive", "bg"),
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
    "DecorationHover": "text-muted",        # hover stays neutral; amber is one thing per view
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


# --- Frames ----------------------------------------------------------------
# Drawn as pixels (whole-pixel rects), never strokes or curves: every piece then measures whole
# pixels, which KSvg needs to lay a frame out without gaps (agents/notes/plasma-svg-frames.md).

SVG_NS = "http://www.w3.org/2000/svg"
FRAME = ["topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom", "bottomright"]
HINTS = ["hint-top-margin", "hint-bottom-margin", "hint-left-margin", "hint-right-margin",
         "hint-top-inset", "hint-bottom-inset", "hint-left-inset", "hint-right-inset"]
EDGE = 32  # length of the edge pieces and side of the center


def white(opacity):
    return ("#ffffff", opacity)


def black(opacity):
    return ("#000000", opacity)


def solid(name):
    return (color(name), 1)


def over(paint, fill):
    """paint laid over fill, as one opaque color: a frame's lines are see-through tints of its fill."""
    (c, o), (base, _) = paint, fill
    mixed = [round(int(c[i:i + 2], 16) * o + int(base[i:i + 2], 16) * (1 - o)) for i in (1, 3, 5)]
    return ("#" + "".join(f"{v:02x}" for v in mixed), 1)


def frame_pixels(sides, fill, cut_corners=True):
    """The 9 pieces of a frame as {piece: (w, h, [(x, y, w, h, (color, opacity))])}.

    sides maps top/bottom/left/right to its lines from the outside in, one color per pixel, all
    the same length t (the frame's thickness). Corners are t x t: each pixel takes the line of the
    side it is nearest to, top and bottom winning ties. With cut_corners, the outermost corner
    pixel is left out and the one inside it takes the outer line, which reads as a 2px radius."""
    t = len(sides["top"])
    sides = {side: [over(paint, fill) for paint in lines] for side, lines in sides.items()}
    pieces = {}

    def corner(name, flip_x, flip_y):
        rects = []
        vertical = sides["bottom" if flip_y else "top"]
        horizontal = sides["right" if flip_x else "left"]
        for y in range(t):
            for x in range(t):
                dy, dx = (t - 1 - y if flip_y else y), (t - 1 - x if flip_x else x)
                if cut_corners and dx == 0 and dy == 0:
                    continue
                if cut_corners and dx == 1 and dy == 1:
                    paint = vertical[0]
                else:
                    paint = vertical[dy] if dy <= dx else horizontal[dx]
                rects.append((x, y, 1, 1, paint))
        pieces[name] = (t, t, rects)

    corner("topleft", False, False)
    corner("topright", True, False)
    corner("bottomleft", False, True)
    corner("bottomright", True, True)
    pieces["top"] = (EDGE, t, [(0, i, EDGE, 1, c) for i, c in enumerate(sides["top"])])
    pieces["bottom"] = (EDGE, t, [(0, t - 1 - i, EDGE, 1, c) for i, c in enumerate(sides["bottom"])])
    pieces["left"] = (t, EDGE, [(i, 0, 1, EDGE, c) for i, c in enumerate(sides["left"])])
    pieces["right"] = (t, EDGE, [(t - 1 - i, 0, 1, EDGE, c) for i, c in enumerate(sides["right"])])
    pieces["center"] = (EDGE, EDGE, [(0, 0, EDGE, EDGE, fill)])
    return pieces


def frame_svg(pieces, prefix, ox, oy):
    """The pieces laid out in a 3x3 grid from (ox, oy), each a <g id="{prefix}{piece}">."""
    t = pieces["topleft"][0]
    cols = {"left": 0, "": t, "right": t + EDGE}
    rows = {"top": 0, "": t, "bottom": t + EDGE}
    out = []
    for name in FRAME:
        row = next((r for r in ("top", "bottom") if name.startswith(r)), "")
        col = next((c for c in ("left", "right") if name.endswith(c)), "")
        _, _, rects = pieces[name]
        shapes = "".join(
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" style="fill:{c};fill-opacity:{o}"/>'
            for x, y, w, h, (c, o) in rects)
        out.append(f'<g id="{prefix}{name}" transform="translate({ox + cols[col]},{oy + rows[row]})">{shapes}</g>')
    return "".join(out)


def mask_of(pieces):
    """The blur/input mask: the frame's own shape in black."""
    return {name: (w, h, [(x, y, rw, rh, black(1)) for x, y, rw, rh, _ in rects])
            for name, (w, h, rects) in pieces.items()}


def rebuild(src, dest_paths, pieces, margin, keep_shadow):
    """Replace a Breeze frame SVG's pieces (and mask) with ours; keep its other elements.
    margin sets the content padding hints; None keeps Breeze's."""
    ET.register_namespace("", SVG_NS)
    root = ET.fromstring(gzip.decompress(src.read_bytes()))
    drop = set(FRAME) | {f"mask-{n}" for n in FRAME}
    if margin is not None:
        drop |= set(HINTS)
    if not keep_shadow:
        drop |= {f"shadow-{n}" for n in FRAME}
    for parent in root.iter():
        for child in list(parent):
            if child.get("id") in drop:
                parent.remove(child)

    oy = float(root.get("height")) + 8  # below everything Breeze has
    size = pieces["topleft"][0] * 2 + EDGE
    extra = frame_svg(pieces, "", 0, oy) + frame_svg(mask_of(pieces), "mask-", size + 8, oy)
    hy = oy + size + 8
    if margin is not None:  # zero-size insets stay as in Breeze
        extra += "".join(f'<rect id="hint-{side}-margin" x="{i * 8}" y="{hy}" width="{margin}" height="{margin}"/>'
                         for i, side in enumerate(("top", "bottom", "left", "right")))
    # Stretch the edge pieces instead of tiling them: tiles meet with a faint seam every 32px
    extra += f'<rect id="hint-stretch-borders" x="40" y="{hy}" width="1" height="1"/>'
    for el in ET.fromstring(f'<g xmlns="{SVG_NS}">{extra}</g>'):
        root.append(el)

    width = max(float(root.get("width")), (size + 8) * 2)
    height = hy + max(margin or 0, 1)
    root.set("width", str(width))
    root.set("height", str(height))
    root.set("viewBox", f"0 0 {width} {height}")
    data = gzip.compress(ET.tostring(root), mtime=0)  # reproducible, so apply.sh can spot changes
    for path in dest_paths:
        dest = OUT / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)


def everywhere(path):
    """A frame used with and without compositing: Plasma picks translucent/, solid/ or the plain one."""
    return [path, f"translucent/{path}", f"solid/{path}"]


def window_sides():
    """A window's engraved edge: `edge` outside, then light top-left and shade bottom-right."""
    light, shade = white(TOKENS["opacity.edge-light"]), black(TOKENS["opacity.edge-shade"])
    return {"top": [solid("edge"), light], "left": [solid("edge"), light],
            "bottom": [solid("edge"), shade], "right": [solid("edge"), shade]}


def build_frames():
    default = SYSTEM / "default/translucent"
    # Popups (bar popups, the launcher, menus) are windows, on `surface`; Breeze's shadow is kept
    popup = frame_pixels(window_sides(), solid("surface"))
    rebuild(default / "dialogs/background.svgz", everywhere("dialogs/background.svgz"),
            popup, margin=4, keep_shadow=True)
    rebuild(default / "widgets/tooltip.svgz", everywhere("widgets/tooltip.svgz"),
            popup, margin=None, keep_shadow=True)
    # The top bar: `bg`, a near-black edge along the side away from the screen edge with an etched
    # line inside it (Plasma leaves out the sides against the screen). Square, no shadow
    line = [solid("edge"), white(TOKENS["opacity.etch"])]
    bar = frame_pixels({"top": line, "bottom": line, "left": line, "right": line}, solid("bg"),
                       cut_corners=False)
    rebuild(default / "widgets/panel-background.svgz", everywhere("widgets/panel-background.svgz"),
            bar, margin=None, keep_shadow=False)


def build_plasmarc():
    rc = (SYSTEM / "breeze-dark/plasmarc").read_text()
    # Opaque always: no see-through panels over an empty desktop either
    rc = rc.replace("[AdaptiveTransparency]\nenabled=true", "[AdaptiveTransparency]\nenabled=false")
    (OUT / "plasmarc").write_text(rc)


def main():
    shutil.rmtree(OUT, ignore_errors=True)
    OUT.mkdir(parents=True)
    shutil.copy(HERE / "metadata.json", OUT)
    build_plasmarc()
    build_colors()
    build_frames()
    print(f"Built {OUT}")


main()
