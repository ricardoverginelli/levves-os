#!/usr/bin/env python3
"""Theme Yakuake and Konsole as "Levves" from design/dist (design/DESIGN.md).

- Konsole color scheme ~/.local/share/konsole/Levves.colorscheme: frosted, the
  terminal on `bg` at opacity.terminal over KWin's blur, ANSI colors from the
  palette. Yakuake's default profile and Konsole's own (Levves.profile) use it,
  with JetBrains Mono and an amber cursor.
- Yakuake skin ~/.local/share/yakuake/skins/levves: the tab bar a flat strip with
  tabs as flat segments (the current one `bg` with a fog line on top), the title
  plane along the bottom with the weak border on its free edge, and the
  decoration's flat glyph keys. Drawn in whole pixels, so it stays crisp.

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
sys.path.insert(0, str(HERE.parent / "shared"))
import changes  # noqa: E402
from levves_tokens import TOKENS, color as palette  # noqa: E402  (the Levves design system)


def px(name):
    return int(TOKENS[name].removesuffix("px"))


TAB_BAR = px("size.key")         # the strip with the tabs
TITLE = px("size.title-bar")     # the title bar along the bottom
TILE = 2                         # width of the tiled strip and bar backgrounds
KEY_W, KEY_H = 22, 18            # the decoration's small keys (kwin-decoration/levves Frame.qml)
KEY_GAP = 4
FROST = TOKENS["opacity.terminal"]
KEY_MARGIN = 5                   # last key to the window's right edge, edge included
TAB_CORNER = 10                  # a tab's ends: 2px of strip, then its key's side
FONT = "JetBrains Mono,9.5,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
LINE_SPACING = 1                 # px between rows: Claude Code's answers breathe a little


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
    lines.extend(["[General]", "Blur=true", "ColorRandomization=false",
                  "Description=Levves", f"Opacity={FROST}", "Wallpaper=", ""])
    return "\n".join(lines)


# --- Yakuake skin ---------------------------------------------------------
# Every image is a list of whole-pixel rects (x, y, w, h, color, opacity), later
# ones over earlier ones; whatever falls outside the image is cut off. Yakuake
# tiles the tab and bar backgrounds; they're frosted like the terminal.

def paint(name):
    """A color token by name, or a color given as is ("#ffffff")."""
    return name if name.startswith("#") else palette(name)


def svg(width, height, rects, extra=""):
    body = "".join(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{paint(c)}"'
                   + (f' fill-opacity="{o}"' if o < 1 else "") + "/>"
                   for x, y, w, h, c, o in rects if w > 0 and h > 0)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}"><g shape-rendering="crispEdges">{body}</g>{extra}</svg>\n')


def current(x, y, w, h):
    """The current tab or a held key (design/qml/Key.qml): `well-pressed` with a 2px fog line on top."""
    return [(x, y, w, h, "well-pressed", FROST), (x, y, w, 2, "fog", 1)]


def key(x, y, state, tone=None):
    """A small flat key at x, y: "up" (the glyph only), "over" (the hover tint, or the tone's) or
    "down". Returns its rects and the center of its face, where the glyph goes."""
    w, h = KEY_W, KEY_H
    if state == "down":
        return current(x, y, w, h), (x + w / 2, y + 1 + h / 2)
    rects = []
    if state == "over":
        tint = (tone, TOKENS["opacity.selection"]) if tone else ("text", TOKENS["opacity.hover"])
        rects.append((x, y, w, h) + tint)
    return rects, (x + w / 2, y + h / 2)


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
    """The strip: frosted `surface`, a hairline on top between it and the terminal."""
    return [(0, 0, width, TAB_BAR, "surface", FROST), (0, 0, width, 1, "border", 1)]


def title_bar(width):
    """The title plane, frosted, the weak border along its free bottom edge."""
    return [(0, 0, width, TITLE, "title-bar", FROST), (0, TITLE - 1, width, 1, "edge", 1)]


def button(background, width, height, key_x, key_y, kind, state):
    critical = "critical" if kind == "close" else None
    rects, center = key(key_x, key_y, state, tone=critical)
    ink = "critical" if critical and state == "over" else "text"
    marks, extra = glyph(kind, center, ink)
    return svg(width, height, background(width) + rects + marks, extra)


KEY_Y = (TAB_BAR - KEY_H) // 2 + 1  # centered under the strip's hairline


def selected_tab(width, left, right):
    """A piece of the current tab: the strip with the current segment across it, edge to edge
    in height; left/right say whether the segment's side is in this piece."""
    x0 = 2 if left else -4
    x1 = width - 2 if right else width + 4
    return svg(width, TAB_BAR, [(0, 0, width, TAB_BAR, "surface", FROST)] + current(x0, 1, x1 - x0, TAB_BAR - 1))


def build_skin():
    files = {}

    # Tab bar: + on the left, × on the right, the tabs between them as flat segments
    strip = lambda w: svg(w, TAB_BAR, tab_bar(w))
    files["tabs/back.svg"] = strip(TILE)
    files["tabs/unselected.svg"] = strip(TILE)
    files["tabs/unselected_corner.svg"] = strip(TAB_CORNER)
    files["tabs/selected.svg"] = selected_tab(TILE, False, False)
    files["tabs/selected_left.svg"] = selected_tab(TAB_CORNER, True, False)
    files["tabs/selected_right.svg"] = selected_tab(TAB_CORNER, False, True)
    lock, _ = glyph("pin", (8, TAB_BAR / 2), "text-muted")
    files["tabs/lock.svg"] = svg(16, TAB_BAR, tab_bar(16) + lock)
    cell = KEY_W + 4  # 4px from the window's edge
    for state in ("up", "over", "down"):
        files[f"tabs/add_{state}.svg"] = button(tab_bar, cell, TAB_BAR, 4, KEY_Y, "add", state)
        files[f"tabs/close_{state}.svg"] = button(tab_bar, cell, TAB_BAR, 0, KEY_Y, "close", state)

    # Title plane: the title on the left, keys on the right
    title_y = (TITLE - 1 - KEY_H) // 2
    files["title/back.svg"] = svg(TILE, TITLE, title_bar(TILE))
    files["title/left.svg"] = svg(14, TITLE, title_bar(14) + [(0, 0, 1, TITLE, "edge", 1)])
    files["title/right.svg"] = svg(KEY_MARGIN, TITLE, title_bar(KEY_MARGIN)
                                   + [(KEY_MARGIN - 1, 0, 1, TITLE, "edge", 1)])
    for name, kind in (("quit", "close"), ("config", "menu"), ("focus", "pin")):
        for state in ("up", "over", "down"):
            files[f"title/{name}_{state}.svg"] = button(title_bar, KEY_W, TITLE, 0, title_y, kind, state)
    files["icon.svg"] = svg(32, 32, [(2, 2, 28, 28, "surface", 1), (2, 2, 28, 3, "fog", 1),
                                     (8, 20, 10, 3, "accent", 1)])

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
x=14
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
        changes.write(profile, f"[General]\nName={fallback}\nParent=FALLBACK/\n")
    return profile, changed


def style_profile(profile):
    """The Levves look on a Konsole profile, keeping its own name and command."""
    changed = False
    for group, key, value in (("Appearance", "ColorScheme", "Levves"), ("Appearance", "Font", FONT),
                              ("Appearance", "LineSpacing", str(LINE_SPACING)),
                              ("Cursor Options", "UseCustomCursorColor", "true"),
                              ("Cursor Options", "CustomCursorColor", ini(palette("accent"))),
                              ("General", "TerminalMargin", "8")):
        changed |= kwrite(profile, group, key, value)
    return changed


def main():
    changed = changes.write(SCHEME, build_scheme())
    changed |= changes.replace_tree(SKIN, build_skin())
    for old in OLD:
        if old.is_dir():
            shutil.rmtree(old)
            changed = True
        elif old.exists():
            old.unlink()
            changed = True

    # Yakuake: our skin, frosted like the terminal; its own fill only shows in gaps
    yakuakerc = CONFIG / "yakuakerc"
    for key, value in (("Skin", "levves"), ("SkinInstalledWithKns", "false"), ("Translucency", "true"),
                       ("BackgroundColor", ini(palette("bg"))), ("BackgroundColorOpacity", str(round(FROST * 100)))):
        changed |= kwrite(yakuakerc, "Appearance", key, value)

    # Yakuake's profile keeps its own name and command. Every new tab opens the terminal
    # launcher (agents/launcher), defaulting to Claude Code in ~/system, the machine's admin
    # home base (its CLAUDE.md describes that machine), through yakuake-tab (os/linux/kwin),
    # which gives Meta+Shift+N tabs a plain shell instead
    profile, picked = default_profile(yakuakerc, "Levves Yakuake")
    changed |= picked | style_profile(profile)
    (Path.home() / "system").mkdir(exist_ok=True)
    changed |= kwrite(profile, "General", "Command", str(Path.home() / ".local/bin/yakuake-tab"))

    # Konsole's own windows: the default shell in a Levves profile, unless another was picked
    profile, picked = default_profile(CONFIG / "konsolerc", "Levves")
    changed |= picked | style_profile(profile)

    changes.report(changed)


if __name__ == "__main__":
    shutil.which("kwriteconfig6") or exit("kwriteconfig6 not found")
    main()
