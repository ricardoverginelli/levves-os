#!/usr/bin/env python3
"""Theme Yakuake and Konsole as "Levves" from design/dist (design/DESIGN.md).

- Konsole color scheme ~/.local/share/konsole/Levves.colorscheme: opaque, the
  terminal on `bg`, ANSI colors from the palette. Yakuake's default profile and
  Konsole's own (Levves.profile) use it, with JetBrains Mono and an amber cursor.
- Yakuake skin ~/.local/share/yakuake/skins/levves: the tab bar a dithered
  strip with tabs as flat keys (the current one held down), the title bar along
  the bottom like D's (the light, then the title), and the decoration's small
  keys for the buttons. Drawn in whole pixels, so it stays crisp.

Prints "changed" when anything was rewritten; Yakuake only picks the skin and
profile up when it restarts.
"""
import configparser
import sys
import shutil
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
DIST = HERE.parents[3] / "design/dist"
CONFIG = Path.home() / ".config"
KONSOLE = Path.home() / ".local/share/konsole"
SCHEME = KONSOLE / "Levves.colorscheme"
SKIN = Path.home() / ".local/share/yakuake/skins/levves"
OLD = [KONSOLE / "Leaves.colorscheme", SKIN.parent / "leaves"]  # the glass look's names

sys.path.insert(0, str(DIST))
from levves_tokens import TOKENS, color as palette  # noqa: E402  (the Levves design system)


def px(name):
    return int(TOKENS[name].removesuffix("px"))


TAB_BAR = px("size.key")         # the dithered strip with the tabs
TITLE = px("size.title-bar")     # the title bar along the bottom
LED = px("size.led")
DITHER = px("size.dither")
KEY_W, KEY_H = 24, 20            # the decoration's small keys (kwin-decoration/levves Frame.qml)
KEY_GAP = 3
KEY_MARGIN = 5                   # last key to the window's right edge, edge included
TAB_CORNER = 10                  # a tab's ends: 2px of strip, then its key's side
FONT = "JetBrains Mono,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"


def rgb(hex_color):
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    """Blend hex color a toward b by t (0..1)."""
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(rgb(a), rgb(b)))


def ini(color):
    return ",".join(map(str, rgb(color)))


# --- Konsole color scheme -------------------------------------------------

def build_scheme():
    # Normal ANSI colors; intense is a step toward white, faint a step toward bg
    ansi = [palette("terminal.black"), palette("critical"), palette("success"), palette("warning"),
            palette("info"), palette("terminal.magenta"), palette("terminal.cyan"), palette("text")]
    lines = []

    def entry(section, color):
        lines.extend([f"[{section}]", f"Color={ini(color)}", ""])

    def triple(section, color, intense):
        entry(section, color)
        entry(section + "Intense", intense)
        entry(section + "Faint", mix(color, palette("bg"), 0.35))

    triple("Background", palette("bg"), palette("bg"))
    triple("Foreground", palette("text"), "#ffffff")
    for i, color in enumerate(ansi):
        intense = palette("terminal.bright-black") if i == 0 else mix(color, "#ffffff", 0.25)
        triple(f"Color{i}", color, intense)
    lines.extend(["[General]", "Blur=false", "ColorRandomization=false",
                  "Description=Levves", "Opacity=1", "Wallpaper=", ""])
    return "\n".join(lines)


# --- Yakuake skin ---------------------------------------------------------
# Every image is a list of whole-pixel rects (x, y, w, h, color, opacity), later
# ones over earlier ones; whatever falls outside the image is cut off. Yakuake
# tiles the tab and bar backgrounds, so those are DITHER wide to keep the
# checkerboard whole.

def paint(name):
    """A color token by name, or a color given as is ("#ffffff")."""
    return name if name.startswith("#") else palette(name)


def svg(width, height, rects, extra=""):
    body = "".join(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{paint(c)}"'
                   + (f' fill-opacity="{o}"' if o < 1 else "") + "/>"
                   for x, y, w, h, c, o in rects if w > 0 and h > 0)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}"><g shape-rendering="crispEdges">{body}</g>{extra}</svg>\n')


def dither(width, height, y0):
    """The strip's checkerboard (design/dist/qml/Levves/dither-strip.svg) over rows y0.."""
    rects = [(0, y0, width, height - y0, "dither-a", 1)]
    for y in range(y0, height):
        rects += [(x, y, 1, 1, "dither-b", 1) for x in range((y + 1) % 2, width, 2)]
    return rects


def outline(x, y, w, h, color):
    """A filled box with its corner pixels cut, which reads as the 3px key radius at this size."""
    return [(x + 1, y, w - 2, 1, color, 1), (x, y + 1, w, h - 2, color, 1), (x + 1, y + h - 1, w - 2, 1, color, 1)]


def sunk(x, y, w, h):
    """A key held down (design/qml/Key.qml): well-pressed in a field-edge outline, a shadow along the top."""
    return outline(x, y, w, h, "field-edge") + [(x + 1, y + 1, w - 2, h - 2, "well-pressed", 1),
                                                (x + 1, y + 1, w - 2, 1, "#000000", 0.5),
                                                (x + 1, y + 2, w - 2, 1, "#000000", 0.25)]


def key(x, y, state, tone=None):
    """A small key at x, y: "up", "over" (the hover tint, or the tone's) or "down". Returns its
    rects and the center of its face, where the glyph goes."""
    w, h = KEY_W, KEY_H
    if state == "down":
        return sunk(x, y, w, h), (x + w / 2, y + 1 + (h - 1) / 2)
    rects = outline(x, y, w, h, "key-depth") + outline(x, y, w, h - 2, "key-edge") \
        + [(x + 1, y + 1, w - 2, h - 3, "raised", 1)]
    if state == "over":
        tint = (tone, TOKENS["opacity.selection"]) if tone else ("text", TOKENS["opacity.hover"])
        rects.append((x + 1, y + 1, w - 2, h - 3) + tint)
    return rects, (x + w / 2, y + (h - 1) / 2)


def glyph(kind, center, ink):
    """The decoration's classic glyphs in whole pixels (the × is antialiased, as there).
    Returns rects and any extra SVG."""
    cx, cy = round(center[0]), round(center[1])
    if kind == "add":
        return [(cx - 4, cy - 1, 8, 2, ink, 1), (cx - 1, cy - 4, 2, 8, ink, 1)], ""
    if kind == "menu":
        return [(cx - 4, cy - 5 + 4 * i, 8, 2, ink, 1) for i in range(3)], ""
    if kind == "pin":  # the decoration's keep-above: a bar over a stem
        return [(cx - 4, cy - 5, 8, 2, ink, 1), (cx - 1, cy - 1, 2, 6, ink, 1)], ""
    d = 11 / 2 / 2 ** 0.5  # close: an X of 11px lines, 1.5px thick
    x, y = center
    path = f"M{x - d:.2f} {y - d:.2f}L{x + d:.2f} {y + d:.2f}M{x + d:.2f} {y - d:.2f}L{x - d:.2f} {y + d:.2f}"
    return [], f'<path d="{path}" stroke="{paint(ink)}" stroke-width="1.5" fill="none"/>'


def tab_bar(width):
    """The strip: the black edge on top, between it and the terminal, then the dither."""
    return [(0, 0, width, 1, "edge", 1)] + dither(width, TAB_BAR, 1)


def title_bar(width):
    """D's title bar on `title-bar`, the black edge along the bottom (Yakuake draws the top one)."""
    return [(0, 0, width, TITLE, "title-bar", 1), (0, TITLE - 1, width, 1, "edge", 1)]


def button(background, width, height, key_x, key_y, kind, state):
    critical = "critical" if kind == "close" else None
    rects, center = key(key_x, key_y, state, tone=critical)
    ink = "critical" if critical and state == "over" else "text"
    marks, extra = glyph(kind, center, ink)
    return svg(width, height, background(width) + rects + marks, extra)


KEY_Y = (TAB_BAR - KEY_H) // 2 + 1  # centered under the strip's edge line


def selected_tab(width, left, right):
    """A piece of the current tab: the strip with a held-down key across it; left/right say
    whether the key's side is in this piece."""
    x0 = 2 if left else -4
    x1 = width - 2 if right else width + 4
    return svg(width, TAB_BAR, tab_bar(width) + sunk(x0, KEY_Y, x1 - x0, KEY_H))


def build_skin():
    files = {}

    # Tab bar: + on the left, × on the right, the tabs between them as flat keys
    strip = lambda w: svg(w, TAB_BAR, tab_bar(w))
    files["tabs/back.svg"] = strip(DITHER)
    files["tabs/unselected.svg"] = strip(DITHER)
    files["tabs/unselected_corner.svg"] = strip(TAB_CORNER)
    files["tabs/selected.svg"] = selected_tab(DITHER, False, False)
    files["tabs/selected_left.svg"] = selected_tab(TAB_CORNER, True, False)
    files["tabs/selected_right.svg"] = selected_tab(TAB_CORNER, False, True)
    lock, _ = glyph("pin", (8, TAB_BAR / 2), "text-muted")
    files["tabs/lock.svg"] = svg(16, TAB_BAR, tab_bar(16) + lock)
    cell = KEY_W + 4  # 4px from the window's edge
    for state in ("up", "over", "down"):
        files[f"tabs/add_{state}.svg"] = button(tab_bar, cell, TAB_BAR, 4, KEY_Y, "add", state)
        files[f"tabs/close_{state}.svg"] = button(tab_bar, cell, TAB_BAR, 0, KEY_Y, "close", state)

    # Title bar: the light and the title on the left, keys on the right
    title_y = (TITLE - 1 - KEY_H) // 2 + 1
    files["title/back.svg"] = svg(DITHER, TITLE, title_bar(DITHER))
    led_x, led_y = 12 + LED / 2, (TITLE - 1) / 2
    led = (f'<circle cx="{led_x}" cy="{led_y}" r="{LED * 1.25}" fill="{palette("accent")}" fill-opacity="0.18"/>'
           f'<circle cx="{led_x}" cy="{led_y}" r="{LED / 2}" fill="{palette("accent")}"/>')
    files["title/left.svg"] = svg(24, TITLE, title_bar(24) + [(0, 0, 1, TITLE, "edge", 1)], led)
    files["title/right.svg"] = svg(KEY_MARGIN, TITLE, title_bar(KEY_MARGIN)
                                   + [(KEY_MARGIN - 1, 0, 1, TITLE, "edge", 1)])
    for name, kind in (("quit", "close"), ("config", "menu"), ("focus", "pin")):
        for state in ("up", "over", "down"):
            files[f"title/{name}_{state}.svg"] = button(title_bar, KEY_W, TITLE, 0, title_y, kind, state)
    files["icon.svg"] = svg(32, 32, [(2, 2, 28, 28, "edge", 1), (3, 3, 26, 26, "title-bar", 1)],
                            f'<circle cx="16" cy="16" r="5" fill="{palette("accent")}"/>')

    text, edge = rgb(palette("text")), rgb(palette("edge"))
    about = "[Description]\nSkin=Levves\nAuthor=Levves (design/dist)\nIcon=/icon.svg\n\n"
    files["tabs.skin"] = about + f"""[Tabs]
x={cell}
y=0
red={text[0]}
green={text[1]}
blue={text[2]}
selected_text_bold=false
selected_background=/tabs/selected.svg
selected_left_corner=/tabs/selected_left.svg
selected_right_corner=/tabs/selected_right.svg
unselected_background=/tabs/unselected.svg
unselected_left_corner=/tabs/unselected_corner.svg
unselected_right_corner=/tabs/unselected_corner.svg
prevent_closing_image=/tabs/lock.svg
prevent_closing_image_x=0
prevent_closing_image_y=0

[Background]
back_image=/tabs/back.svg
left_corner=/tabs/back.svg
right_corner=/tabs/back.svg

[PlusButton]
x=0
y=0
up_image=/tabs/add_up.svg
over_image=/tabs/add_over.svg
down_image=/tabs/add_down.svg

[MinusButton]
x={cell}
y=0
up_image=/tabs/close_up.svg
over_image=/tabs/close_over.svg
down_image=/tabs/close_down.svg
"""
    # Keys from the right: quit, menu, pin (x is from the window's right edge to the key's left)
    quit_x = KEY_MARGIN + KEY_W
    files["title.skin"] = about + f"""[Border]
red={edge[0]}
green={edge[1]}
blue={edge[2]}
width=1

[Text]
x={12 + LED + 8}
y=19
red={text[0]}
green={text[1]}
blue={text[2]}
bold=false
text=

[Background]
back_image=/title/back.svg
left_corner=/title/left.svg
right_corner=/title/right.svg

[FocusButton]
x={quit_x + 2 * (KEY_W + KEY_GAP)}
y=0
up_image=/title/focus_up.svg
over_image=/title/focus_over.svg
down_image=/title/focus_down.svg

[ConfigButton]
x={quit_x + KEY_W + KEY_GAP}
y=0
up_image=/title/config_up.svg
over_image=/title/config_over.svg
down_image=/title/config_down.svg

[QuitButton]
x={quit_x}
y=0
up_image=/title/quit_up.svg
over_image=/title/quit_over.svg
down_image=/title/quit_down.svg
"""
    return files


# --- Install --------------------------------------------------------------

def write(path, text):
    if path.exists() and path.read_text() == text:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return True


def kwrite(file, group, key, value):
    current = subprocess.run(["kreadconfig6", "--file", str(file), "--group", group, "--key", key],
                             capture_output=True, text=True).stdout.strip()
    if current == value:
        return False
    subprocess.run(["kwriteconfig6", "--file", str(file), "--group", group, "--key", key, value], check=True)
    return True


def default_profile(rc, fallback):
    """The profile an app starts with, made (and picked) as `fallback` when it has none."""
    cfg = configparser.ConfigParser(interpolation=None, strict=False)
    cfg.read(rc)
    name = cfg.get("Desktop Entry", "DefaultProfile", fallback="")
    changed = False
    if not name:
        name = f"{fallback}.profile"
        changed = kwrite(rc, "Desktop Entry", "DefaultProfile", name)
    profile = KONSOLE / name
    if not profile.exists():
        write(profile, f"[General]\nName={fallback}\nParent=FALLBACK/\n")
    return profile, changed


def style_profile(profile):
    """The Levves look on a Konsole profile, keeping its own name and command."""
    changed = False
    for group, key, value in (("Appearance", "ColorScheme", "Levves"), ("Appearance", "Font", FONT),
                              ("Cursor Options", "UseCustomCursorColor", "true"),
                              ("Cursor Options", "CustomCursorColor", ini(palette("accent"))),
                              ("General", "TerminalMargin", "8")):
        changed |= kwrite(profile, group, key, value)
    return changed


def main():
    changed = write(SCHEME, build_scheme())

    skin = build_skin()
    stale = {p.relative_to(SKIN).as_posix() for p in SKIN.rglob("*") if p.is_file()} - set(skin) if SKIN.exists() else set()
    for name in stale:
        (SKIN / name).unlink()
        changed = True
    for name, text in skin.items():
        changed |= write(SKIN / name, text)
    for old in OLD:
        if old.is_dir():
            shutil.rmtree(old)
            changed = True
        elif old.exists():
            old.unlink()
            changed = True

    # Yakuake: our skin, opaque; its own fill only shows in gaps, so it's the terminal's
    yakuakerc = CONFIG / "yakuakerc"
    for key, value in (("Skin", "levves"), ("SkinInstalledWithKns", "false"), ("Translucency", "false"),
                       ("BackgroundColor", ini(palette("bg"))), ("BackgroundColorOpacity", "100")):
        changed |= kwrite(yakuakerc, "Appearance", key, value)

    # Yakuake's profile keeps its own name and command. Every new tab starts Claude Code in
    # ~/system, the machine's admin home base (its CLAUDE.md describes that machine), through
    # yakuake-tab (os/linux/kwin), which gives Meta+Shift+N tabs a plain shell instead
    profile, picked = default_profile(yakuakerc, "Levves Yakuake")
    changed |= picked | style_profile(profile)
    (Path.home() / "system").mkdir(exist_ok=True)
    changed |= kwrite(profile, "General", "Command", str(Path.home() / ".local/bin/yakuake-tab"))

    # Konsole's own windows: the default shell in a Levves profile, unless another was picked
    profile, picked = default_profile(CONFIG / "konsolerc", "Levves")
    changed |= picked | style_profile(profile)

    if changed:
        print("changed")


if __name__ == "__main__":
    shutil.which("kwriteconfig6") or exit("kwriteconfig6 not found")
    main()
