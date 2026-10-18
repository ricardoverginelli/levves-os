#!/usr/bin/env python3
"""Install the Leaves icons into the user's hicolor theme (run by apply.sh).

MingCute SVGs install as mingcute-<name>, our own drawings (custom/) as
leaves-<name>. On the way they get KDE's recoloring convention: a
ColorScheme-Text stylesheet and class on every currentColor shape. Without it,
KDE's icon loader can't tint them and they render black. Prints "changed" when
anything was written (Plasma caches icons, so it needs a restart).
"""
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEST = Path.home() / ".local/share/icons/hicolor/scalable/actions"
STYLE = '<style type="text/css" id="current-color-scheme">.ColorScheme-Text { color: #fcfcfc; }</style>'


def kde_svg(svg):
    # Tag every element that paints with currentColor (filled or stroked shapes)
    def tag(m):
        element = m.group(0)
        if "currentColor" not in element or "ColorScheme-Text" in element or element.startswith("<svg"):
            return element
        return element.replace(" ", ' class="ColorScheme-Text" ', 1)
    svg = re.sub(r"<[a-zA-Z][^>]*>", tag, svg)
    return re.sub(r"(<svg\b[^>]*>)", r"\1" + STYLE, svg, count=1)


changed = False
DEST.mkdir(parents=True, exist_ok=True)
for folder, prefix in (("mingcute", "mingcute"), ("custom", "leaves")):
    for src in sorted((HERE / folder).glob("*.svg")):
        dest = DEST / f"{prefix}-{src.name}"
        text = kde_svg(src.read_text())
        if not dest.exists() or dest.read_text() != text:
            dest.write_text(text)
            changed = True
if changed:
    (Path.home() / ".cache/icon-cache.kcache").unlink(missing_ok=True)
    print("changed")
