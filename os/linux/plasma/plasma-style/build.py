#!/usr/bin/env python3
"""Build the "Leaves" Plasma style from the Levves tokens into ~/.local/share/plasma/desktoptheme/leaves,
and the apps' color scheme "Levves" (~/.local/share/color-schemes/Levves.colors) from the same palette.

Starts from the Breeze Dark style installed on this machine (so it tracks Plasma updates), swaps
in the Levves colors and redraws the frames of panels, popups and tooltips as Urban Flora draws
shell panes (design/DESIGN.md Surfaces): frosted (translucent over KWin's blur; solid where Plasma
has no compositing), the weak fog border and the top-right cut. Controls are flat planes.
Everything not overridden falls back to the stock "default" style.
"""
import configparser
import gzip
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
SYSTEM = Path("/usr/share/plasma/desktoptheme")
OUT = Path.home() / ".local/share/plasma/desktoptheme/leaves"
SCHEMES = Path.home() / ".local/share/color-schemes"

sys.path.insert(0, str(HERE.parents[3] / "design/dist"))
from levves_tokens import TOKENS, color  # noqa: E402  (the Levves design system)



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
    "Selection": ("raised", "surface"),
}
FOREGROUNDS = {
    "ForegroundNormal": "text",
    "ForegroundInactive": "text-muted",
    "ForegroundActive": "fog",
    "ForegroundLink": "fog",
    "ForegroundVisited": "fog-deep",
    "ForegroundNegative": "critical",
    "ForegroundNeutral": "warning",
    "ForegroundPositive": "success",
    "DecorationFocus": "fog",               # focus is fog; amber is the primary key only
    "DecorationHover": "text-muted",
}


def scheme(base):
    """A Breeze Dark color scheme with the Levves palette: the Plasma style's `colors` or the apps'."""
    colors = configparser.ConfigParser(interpolation=None, strict=False)
    colors.optionxform = str  # keep key case
    colors.read(base)
    for color_set, (normal, alternate) in BACKGROUNDS.items():
        section = f"Colors:{color_set}"
        if not colors.has_section(section):
            colors.add_section(section)
        colors[section]["BackgroundNormal"] = rgb(normal)
        colors[section]["BackgroundAlternate"] = rgb(alternate)
        for key, role in FOREGROUNDS.items():
            colors[section][key] = rgb(role)
    return colors


def build_colors():
    # Plasma's selection is Urban Flora's: fog at opacity.selection under normal text. Plasma also
    # takes the selection's text color for pressed and checked buttons, which sink into `well-pressed`
    style = scheme(SYSTEM / "breeze-dark/colors")
    tint = over(on("fog", TOKENS["opacity.selection"]), solid("surface"))[0].lstrip("#")
    style["Colors:Selection"]["BackgroundNormal"] = ",".join(str(int(tint[i:i + 2], 16)) for i in (0, 2, 4))
    with open(OUT / "colors", "w") as f:
        style.write(f, space_around_delimiters=False)

    # The apps' scheme: the same sets on Breeze Dark's app scheme (keeping its effects for disabled
    # text) and the decoration's title plane colors
    colors = scheme(Path("/usr/share/color-schemes/BreezeDark.colors"))
    colors["General"] = {"ColorScheme": "Levves", "Name": "Levves", "shadeSortColumn": "false"}
    colors["WM"] = {
        "activeBackground": rgb("title-bar"), "activeForeground": rgb("text"), "activeBlend": rgb("fog"),
        "inactiveBackground": rgb("title-bar-inactive"), "inactiveForeground": rgb("text-muted"),
        "inactiveBlend": rgb("border"),
    }
    colors["ColorEffects:Inactive"]["ChangeSelectionColor"] = "true"
    colors["ColorEffects:Inactive"]["Enable"] = "false"
    SCHEMES.mkdir(parents=True, exist_ok=True)
    with open(SCHEMES / "Levves.colors", "w") as f:
        colors.write(f, space_around_delimiters=False)


# --- Frames ----------------------------------------------------------------
# Drawn as pixels (whole-pixel rects), never strokes or curves: every piece then measures whole
# pixels, which KSvg needs to lay a frame out without gaps (os/linux/notes/plasma-svg-frames.md).

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


def frame_pixels(sides, fill, cut_corners=True, blend=True):
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


def pane_pixels(fill, line, cut=0):
    """A shell pane's 9 pieces: `fill` inside a 1px `line`, with the top-right corner cut at 45
    degrees by `cut` pixels (the pixels past the diagonal left out, the diagonal itself drawn as a
    1px staircase in `line`). The frame is cut + 1 pixels thick so the whole cut fits in the
    top-right piece; content margins come from hints, not from this thickness."""
    t = max(1, cut + 1)
    pieces = {}

    def corner(name, flip_x, flip_y):
        rects = []
        for y in range(t):
            for x in range(t):
                dx, dy = (t - 1 - x if flip_x else x), (t - 1 - y if flip_y else y)
                if name == "topright" and cut and dx + dy < cut:
                    continue  # past the cut
                on_edge = dx == 0 or dy == 0 or (name == "topright" and cut and dx + dy == cut)
                rects.append((x, y, 1, 1, line if on_edge else fill))
        pieces[name] = (t, t, rects)

    corner("topleft", False, False)
    corner("topright", True, False)
    corner("bottomleft", False, True)
    corner("bottomright", True, True)
    inner = [fill] * (t - 1)
    pieces["top"] = (EDGE, t, [(0, i, EDGE, 1, c) for i, c in enumerate([line] + inner)])
    pieces["bottom"] = (EDGE, t, [(0, t - 1 - i, EDGE, 1, c) for i, c in enumerate([line] + inner)])
    pieces["left"] = (t, EDGE, [(i, 0, 1, EDGE, c) for i, c in enumerate([line] + inner)])
    pieces["right"] = (t, EDGE, [(t - 1 - i, 0, 1, EDGE, c) for i, c in enumerate([line] + inner)])
    pieces["center"] = (EDGE, EDGE, [(0, 0, EDGE, EDGE, fill)])
    return pieces


def build_frames():
    default = SYSTEM / "default/translucent"
    # Frosted where KWin composites (translucent/: the fill at its opacity token, the border in fog
    # at opacity.outline, both over KWin's blur), solid otherwise (solid/ and the plain one)
    frost = {"pane": on("surface", TOKENS["opacity.pane"]), "bar": on("bg", TOKENS["opacity.bar"])}
    weak = on("fog", TOKENS["opacity.outline"])
    cut = int(TOKENS["cut.pane"].rstrip("px"))

    def both(src, path, fill, margin, keep_shadow, cut=0, border=True):
        opaque = solid("surface" if fill == "pane" else "bg")
        rebuild(src, [f"translucent/{path}"], pane_pixels(frost[fill], weak if border else frost[fill], cut),
                margin, keep_shadow)
        rebuild(src, [path, f"solid/{path}"], pane_pixels(opaque, solid("edge") if border else opaque, cut),
                margin, keep_shadow)

    # Popups (bar popups, the launcher, menus) are panes with the cut; Breeze's shadow is kept
    both(default / "dialogs/background.svgz", "dialogs/background.svgz", "pane", 4, True, cut)
    # Tooltips are too small for the cut
    both(default / "widgets/tooltip.svgz", "widgets/tooltip.svgz", "pane", None, True)
    # The top bar: frosted `bg`, square, no border and no shadow: it's part of the screen's edge,
    # not something floating over it
    both(default / "widgets/panel-background.svgz", "widgets/panel-background.svgz", "bar", None, False,
         border=False)


# --- Controls --------------------------------------------------------------
# Plasma's own controls (PlasmaComponents: buttons, fields, sliders, switches...) draw from these.
# A file here replaces Breeze's whole, so each holds every element the controls ask for; elements
# left out (shadows) draw nothing. Hint margins are Breeze's, so layouts don't move.

CLEAR = ("#000000", 0)


def on(name, opacity):
    return (color(name), opacity)


def all_sides(lines):
    return {side: list(lines) for side in ("top", "bottom", "left", "right")}


def key_frame(face):
    """A key: a flat square plane."""
    return frame_pixels(all_sides([face, face]), face, cut_corners=False)


def sunk_frame():
    """A pressed, checked or current key: `well-pressed` with a 2px fog line along the top."""
    wp, fog = solid("well-pressed"), solid("fog")
    return frame_pixels({"top": [fog, fog], "left": [wp, wp], "right": [wp, wp], "bottom": [wp, wp]},
                        wp, cut_corners=False)


def ring(paint, thickness=1):
    """An outline laid over a control (hover, focus), clear inside."""
    return frame_pixels(all_sides([paint] + [CLEAR] * (thickness - 1)), CLEAR, blend=False)


def tint_frame(paint, cut_corners=True):
    return frame_pixels(all_sides([paint]), paint, cut_corners=cut_corners, blend=False)


def rect_svg(rects):
    return "".join(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" style="fill:{c};fill-opacity:{o}"/>'
                   for x, y, w, h, (c, o) in rects if o > 0)


def hint_rects(prefix, margins, y):
    """Content margins for a frame: KSvg reads a hint's height (top/bottom) or width (left/right)."""
    out = ""
    for i, side in enumerate(("top", "bottom", "left", "right")):
        m = margins[side] if isinstance(margins, dict) else margins
        m = m or 0.001  # a zero-size element counts as missing
        w, h = (1, m) if side in ("top", "bottom") else (m, 1)
        out += f'<rect id="{prefix}-hint-{side}-margin" x="{i * 8}" y="{y}" width="{w}" height="{h}"/>'
    return out


def write_widget(name, frames=(), shapes=(), hints=()):
    """widgets/{name}.svgz from frames [(prefix, pieces, margins or None)], shapes [(id, w, h, svg)]
    and bare hint elements [(id, w, h)]."""
    body, y, width = "", 0, 64
    for prefix, pieces, margins in frames:
        size = pieces["topleft"][0] * 2 + EDGE
        body += frame_svg(pieces, f"{prefix}-", 0, y)
        if margins is not None:
            body += hint_rects(prefix, margins, y + size + 4)
            size += 16
        y += size + 8
        width = max(width, size)
    x = 0
    for element, w, h, svg in shapes:
        body += f'<g id="{element}" transform="translate({x},{y})"><rect width="{w}" height="{h}" style="fill:none"/>{svg}</g>'
        x += w + 8
    y += max([h for _, _, h, _ in shapes], default=0) + 8
    width = max(width, x)
    for i, (element, w, h) in enumerate(hints):
        body += f'<rect id="{element}" x="{i * 48}" y="{y}" width="{w}" height="{h}" style="fill:none"/>'
    y += 48
    body += f'<rect id="hint-stretch-borders" x="{width + 8}" y="0" width="1" height="1"/>'
    svg = (f'<svg xmlns="{SVG_NS}" width="{width + 16}" height="{y}" viewBox="0 0 {width + 16} {y}">'
           f'{body}</svg>')
    dest = OUT / "widgets" / f"{name}.svgz"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(gzip.compress(svg.encode(), mtime=0))


def circle(r, cx, cy, fill=None, stroke=None):
    f = f"fill:{fill[0]};fill-opacity:{fill[1]}" if fill else "fill:none"
    st = f";stroke:{stroke[0]};stroke-opacity:{stroke[1]};stroke-width:1" if stroke else ""
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" style="{f}{st}"/>'


def build_controls():
    raised, fog = solid("raised"), solid("fog")
    hover_tint = on("text", TOKENS["opacity.hover"])
    hover_face = over(hover_tint, raised)

    # Buttons are keys: flat `raised` planes; pressed or checked they sink to `well-pressed` with a
    # fog line. Hover lightens the face (drawn over the key, so no margins); focus is a fog ring 1px
    # outside it. Flat (tool) buttons show only a tint
    write_widget("button", frames=[
        ("normal", key_frame(raised), 6),
        ("pressed", sunk_frame(), 6),
        ("hover", key_frame(hover_face), 0),
        ("focus", ring(fog, 2), 2),
        ("toolbutton-hover", tint_frame(hover_tint), 4),
        ("toolbutton-pressed", sunk_frame(), 4),
    ])

    # Fields are openings: `bg-deep` inside the weak `field-edge` outline, fog while focused
    well, deep = solid("well"), solid("bg-deep")
    field = frame_pixels(all_sides([solid("field-edge"), deep]), deep, cut_corners=False)
    write_widget("lineedit", frames=[
        ("base", field, 6),
        ("hover", ring(on("fog", 0.45)), 0),
        ("focus", ring(fog), 0),
    ], hints=[("hint-focus-over-base", 2, 2)])

    # List rows: square, a hover tint, the selection in fog at opacity.selection
    selection = TOKENS["opacity.selection"]
    write_widget("viewitem", frames=[
        ("normal", tint_frame(CLEAR, False), 5),
        ("hover", tint_frame(hover_tint, False), 5),
        ("selected", tint_frame(on("fog", selection), False), 5),
        ("selected+hover", tint_frame(on("fog", selection + TOKENS["opacity.hover"]), False), 5),
    ])

    # Sliders like the Levves Slider: a flat 6px `raised` track, the part up to the value in fog,
    # and a narrow square thumb in `text-soft` (`text` on hover)
    groove = frame_pixels(all_sides([raised] * 3), raised, cut_corners=False)
    highlight = frame_pixels(all_sides([fog] * 3), fog, cut_corners=False)

    def thumb(horizontal, face):
        w, h = (6, 16) if horizontal else (16, 6)
        return rect_svg([((20 - w) // 2, (20 - h) // 2, w, h, face)])

    def thumb_ring(horizontal):
        w, h = (10, 20) if horizontal else (20, 10)
        x, y = (24 - w) // 2, (24 - h) // 2
        return rect_svg([(x, y, w, 1, fog), (x, y + h - 1, w, 1, fog), (x, y, 1, h, fog), (x + w - 1, y, 1, h, fog)])

    write_widget("slider", frames=[("groove", groove, None), ("groove-highlight", highlight, None)], shapes=[
        ("horizontal-slider-handle", 20, 20, thumb(True, solid("text-soft"))),
        ("horizontal-slider-hover", 20, 20, thumb(True, solid("text"))),
        ("horizontal-slider-focus", 24, 24, thumb_ring(True)),
        ("vertical-slider-handle", 20, 20, thumb(False, solid("text-soft"))),
        ("vertical-slider-hover", 20, 20, thumb(False, solid("text"))),
        ("vertical-slider-focus", 24, 24, thumb_ring(False)),
    ], hints=[("hint-handle-size", 20, 20)])

    # Switches: a flat `raised` slot and a square knob, `text-faint` when off and fog when on
    def slot_piece(piece, w):
        return rect_svg([(0, 0, w, 16, raised)])

    def knob(ink):
        return rect_svg([(2, 2, 12, 12, ink)])

    slot = [(f"{state}-{piece}", w, 16, slot_piece(piece, w))
            for state in ("inactive", "active") for piece, w in (("left", 8), ("center", 5), ("right", 8))]
    write_widget("switch", shapes=slot + [
        ("handle", 16, 16, knob(solid("text-faint"))),
        ("handle-active", 16, 16, knob(fog)),
        ("handle-hover", 16, 16, knob(solid("text-soft"))),
        ("handle-pressed", 16, 16, knob(solid("text-muted"))),
        ("handle-focus", 20, 20, rect_svg([(2, 2, 16, 1, fog), (2, 17, 16, 1, fog),
                                           (2, 2, 1, 16, fog), (17, 2, 1, 16, fog)])),
    ], hints=[("hint-bar-size", 38, 16)])

    # Radios: a round opening like a field; the dot in fog
    write_widget("radiobutton", shapes=[
        ("normal", 16, 16, circle(7.5, 8, 8, fill=deep, stroke=solid("field-edge"))),
        ("checked", 16, 16, circle(3, 8, 8, fill=fog)),
        ("hover", 16, 16, circle(7.5, 8, 8, stroke=on("fog", 0.45))),
        ("focus", 20, 20, circle(9.5, 10, 10, stroke=fog)),
        ("symbol", 6, 6, circle(3, 3, 3, fill=solid("text"))),
    ], hints=[("hint-size", 16, 16)])

    # The check drawn into a checkbox (the box itself is the button's "normal" key)
    text = color("text")
    write_widget("checkmarks", shapes=[
        ("checkbox", 16, 16, f'<path d="M4 8.5 L7 11.5 L12.5 5" style="fill:none;stroke:{text};stroke-width:2"/>'),
        ("radiobutton", 16, 16, circle(3, 8, 8, fill=solid("text"))),
    ])

    # Tabs are flat segments; the current one is `well-pressed` with the fog line on top. Margins as
    # a key's, not Breeze's (its underline needed room)
    write_widget("tabbar", frames=[(f"{side}-active-tab", sunk_frame(), dict(left=10, right=10, top=6, bottom=6))
                                   for side in ("north", "south", "east", "west")])

    # Progress bars and meters: a flat `raised` track, the fill in fog
    write_widget("bar_meter_horizontal", frames=[
        ("bar-inactive", frame_pixels(all_sides([raised]), raised, cut_corners=False), None),
        ("bar-active", frame_pixels(all_sides([fog]), fog, cut_corners=False), None),
    ], hints=[("hint-bar-size", 6, 6)])


def build_plasmarc():
    rc = (SYSTEM / "breeze-dark/plasmarc").read_text()
    # No adaptive transparency: the bar stays frosted whether or not a window is maximized
    rc = rc.replace("[AdaptiveTransparency]\nenabled=true", "[AdaptiveTransparency]\nenabled=false")
    (OUT / "plasmarc").write_text(rc)


def main():
    shutil.rmtree(OUT, ignore_errors=True)
    OUT.mkdir(parents=True)
    shutil.copy(HERE / "metadata.json", OUT)
    build_plasmarc()
    build_colors()
    build_frames()
    build_controls()
    print(f"Built {OUT}")


main()
