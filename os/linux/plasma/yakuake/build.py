#!/usr/bin/env python3
"""Theme Yakuake as "Leaves" from ../palette.json.

- Konsole color scheme ~/.local/share/konsole/Leaves.colorscheme (glass: bg at
  glass-opacity with KWin blur), used by Yakuake's default profile along with
  JetBrains Mono and an amber cursor.
- Yakuake skin ~/.local/share/yakuake/skins/leaves: tab bar and title bar drawn
  as SVGs in the palette, MingCute icons for the buttons.

Prints "changed" when anything was rewritten; Yakuake only picks the skin and
profile up when it restarts.
"""
import configparser
import json
import re
import shutil
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
ICONS = HERE.parent / "icons"
CONFIG = Path.home() / ".config"
SCHEME = Path.home() / ".local/share/konsole/Leaves.colorscheme"
SKIN = Path.home() / ".local/share/yakuake/skins/leaves"

palette = json.loads((HERE.parent / "palette.json").read_text())
glass = palette["glass-opacity"]

BAR = 28      # tab bar and title bar height (DESIGN.md: top bar is 28px too)
BUTTON = 28   # square buttons; 16px icon centered
PAD = 8       # space either side of a tab's title
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
    t = palette["terminal"]
    # Normal ANSI colors; intense is a step toward white, faint a step toward bg
    ansi = [t["black"], palette["critical"], palette["success"], palette["warning"],
            palette["info"], t["magenta"], t["cyan"], palette["text"]]
    lines = []

    def entry(section, color):
        lines.extend([f"[{section}]", f"Color={ini(color)}", ""])

    def triple(section, color, intense):
        entry(section, color)
        entry(section + "Intense", intense)
        entry(section + "Faint", mix(color, palette["bg"], 0.35))

    triple("Background", palette["bg"], palette["bg"])
    triple("Foreground", palette["text"], "#ffffff")
    for i, color in enumerate(ansi):
        intense = t["bright-black"] if i == 0 else mix(color, "#ffffff", 0.25)
        triple(f"Color{i}", color, intense)
    lines.extend(["[General]", "Blur=true", "ColorRandomization=false",
                  "Description=Leaves", f"Opacity={glass}", "Wallpaper=", ""])
    return "\n".join(lines)


# --- Yakuake skin ---------------------------------------------------------

def svg(width, height, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}">{body}</svg>\n')


def rect(x, y, w, h, color, opacity=1, rx=0):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" '
            f'fill="{palette.get(color, color)}" fill-opacity="{opacity}"/>')


def icon(name, color, size=16, x=None, y=None):
    """A 24px icon (MingCute or custom) scaled to size, in a palette color."""
    folder, file = ("custom", name[len("leaves-"):]) if name.startswith("leaves-") else ("mingcute", name)
    source = (ICONS / folder / f"{file}.svg").read_text()
    body = re.search(r"<svg[^>]*>(.*)</svg>", source, re.S).group(1)
    body = body.replace("currentColor", palette[color])
    x = (BUTTON - size) / 2 if x is None else x
    y = (BAR - size) / 2 if y is None else y
    return f'<g transform="translate({x} {y}) scale({size / 24})">{body}</g>'


def bar_fill(width, line="border"):
    """Glass fill, with a 1px line on top separating the bar from the terminal."""
    body = rect(0, 0, width, BAR, "bg", glass)
    if line:
        body += rect(0, 0, width, 1, line)
    return body


def button(fill, name, color, hover=False):
    body = fill(BUTTON)
    if hover:  # neutral hover tint (DESIGN.md: text at 6%), 8px corners
        body += rect(2, 2, BUTTON - 4, BAR - 4, "text", 0.06, rx=8)
    return svg(BUTTON, BAR, body + icon(name, color))


def build_skin():
    files = {}

    # Tab bar: 1px border line on top; the selected tab gets a 2px accent line
    # and a neutral tint instead (the one accented thing in the view)
    tab = svg(1, BAR, bar_fill(1))
    selected = svg(1, BAR, bar_fill(1, line=None) + rect(0, 0, 1, BAR, "text", 0.06)
                   + rect(0, 0, 1, 2, "accent"))
    files["tabs/back.svg"] = tab
    files["tabs/unselected.svg"] = tab
    files["tabs/unselected_pad.svg"] = svg(PAD, BAR, bar_fill(PAD))
    files["tabs/selected.svg"] = selected
    files["tabs/selected_pad.svg"] = svg(PAD, BAR, bar_fill(PAD, line=None)
                                         + rect(0, 0, PAD, BAR, "text", 0.06) + rect(0, 0, PAD, 2, "accent"))
    files["tabs/lock.svg"] = svg(16, BAR, icon("lock-fill", "text-muted", x=0))
    for name, image in (("add", "add-fill"), ("close", "close-fill")):
        files[f"tabs/{name}_up.svg"] = button(bar_fill, image, "text-muted")
        files[f"tabs/{name}_over.svg"] = button(bar_fill, image, "text", hover=True)

    # Title bar: same glass, no top line (Yakuake draws a border line above it)
    title = lambda w: bar_fill(w, line=None)
    files["title/back.svg"] = svg(1, BAR, title(1))
    for name, image in (("quit", "close-fill"), ("config", "menu-fill"), ("focus", "pin-fill")):
        files[f"title/{name}_up.svg"] = button(title, image, "text-muted")
        files[f"title/{name}_over.svg"] = button(title, image, "text", hover=True)
    # Focus button's checked state (stays open on focus loss) is the accented one
    files["title/focus_down.svg"] = button(title, "pin-fill", "accent", hover=True)
    files["icon.svg"] = svg(32, 32, icon("leaves-leaf", "accent", size=24, x=4, y=4))

    r, g, b = rgb(palette["text"])
    mr, mg, mb = rgb(palette["text-muted"])
    br, bg_, bb = rgb(palette["border"])
    about = "[Description]\nSkin=Leaves\nAuthor=Leaves (palette.json)\nIcon=/icon.svg\n\n"
    files["tabs.skin"] = about + f"""[Tabs]
x={BUTTON}
y=0
red={r}
green={g}
blue={b}
selected_text_bold=false
selected_background=/tabs/selected.svg
selected_left_corner=/tabs/selected_pad.svg
selected_right_corner=/tabs/selected_pad.svg
unselected_background=/tabs/unselected.svg
unselected_left_corner=/tabs/unselected_pad.svg
unselected_right_corner=/tabs/unselected_pad.svg
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
down_image=/tabs/add_over.svg

[MinusButton]
x={BUTTON}
y=0
up_image=/tabs/close_up.svg
over_image=/tabs/close_over.svg
down_image=/tabs/close_over.svg
"""
    files["title.skin"] = about + f"""[Border]
red={br}
green={bg_}
blue={bb}
width=1

[Text]
x=12
y=19
red={mr}
green={mg}
blue={mb}
bold=false
text=

[Background]
back_image=/title/back.svg
left_corner=/title/back.svg
right_corner=/title/back.svg

[FocusButton]
x={3 * BUTTON}
y=0
up_image=/title/focus_up.svg
over_image=/title/focus_over.svg
down_image=/title/focus_down.svg

[ConfigButton]
x={2 * BUTTON}
y=0
up_image=/title/config_up.svg
over_image=/title/config_over.svg
down_image=/title/config_over.svg

[QuitButton]
x={BUTTON}
y=0
up_image=/title/quit_up.svg
over_image=/title/quit_over.svg
down_image=/title/quit_over.svg
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


def main():
    changed = write(SCHEME, build_scheme())

    skin = build_skin()
    stale = {p.relative_to(SKIN).as_posix() for p in SKIN.rglob("*") if p.is_file()} - set(skin) if SKIN.exists() else set()
    for name in stale:
        (SKIN / name).unlink()
        changed = True
    for name, text in skin.items():
        changed |= write(SKIN / name, text)

    # Yakuake: our skin; no window fill of its own, so the terminal and the
    # skin's bars carry the glass alone
    yakuakerc = CONFIG / "yakuakerc"
    for key, value in (("Skin", "leaves"), ("SkinInstalledWithKns", "false"), ("Translucency", "true"),
                       ("BackgroundColor", ini(palette["bg"])), ("BackgroundColorOpacity", "0")):
        changed |= kwrite(yakuakerc, "Appearance", key, value)

    # Yakuake's profile (keeps its own command and name), or a new Leaves one
    cfg = configparser.ConfigParser(interpolation=None, strict=False)
    cfg.read(yakuakerc)
    name = cfg.get("Desktop Entry", "DefaultProfile", fallback="")
    if not name:
        name = "Leaves.profile"
        changed |= kwrite(yakuakerc, "Desktop Entry", "DefaultProfile", name)
    profile = SCHEME.parent / name
    if not profile.exists():
        write(profile, "[General]\nName=Leaves\nParent=FALLBACK/\n")
    # Every new Yakuake tab starts Claude Code in ~/system, the machine's admin
    # home base (its CLAUDE.md describes that machine), through yakuake-tab
    # (linux/kwin), which gives Meta+Shift+N tabs a plain shell instead
    (Path.home() / "system").mkdir(exist_ok=True)
    for group, key, value in (("Appearance", "ColorScheme", "Leaves"), ("Appearance", "Font", FONT),
                              ("Cursor Options", "UseCustomCursorColor", "true"),
                              ("Cursor Options", "CustomCursorColor", ini(palette["accent"])),
                              ("General", "TerminalMargin", "8"),
                              ("General", "Command", str(Path.home() / ".local/bin/yakuake-tab"))):
        changed |= kwrite(profile, group, key, value)

    if changed:
        print("changed")


if __name__ == "__main__":
    shutil.which("kwriteconfig6") or exit("kwriteconfig6 not found")
    main()
