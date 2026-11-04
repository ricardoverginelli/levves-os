"""Qt helpers for the Levves desktop apps: MingCute icons tinted in a token color (design/DESIGN.md Icons).

Put design/dist on sys.path, then:

    from levves_qt import IconProvider, tinted
    engine.addImageProvider("icon", IconProvider())   # image://icon/<name>?color=rrggbb
    tray.setIcon(QIcon(tinted("mingcute-midi-fill", color("accent"), QSize(22, 22))))

Names are `mingcute-<name>` or `leaves-<name>` (our own drawings), as installed for Plasma; a bare
name is a MingCute one. The SVGs are read from the repo, so nothing has to be installed first.
"""
from pathlib import Path

from levves_tokens import color
from PySide6.QtCore import QByteArray, QSize, Qt
from PySide6.QtGui import QPainter, QPixmap
from PySide6.QtQuick import QQuickImageProvider
from PySide6.QtSvg import QSvgRenderer

ICONS = Path(__file__).resolve().parents[2] / "os/linux/plasma/icons"


def icon_file(name):
    """The SVG behind an icon name."""
    if name.startswith("leaves-"):
        return ICONS / "custom" / f"{name.removeprefix('leaves-')}.svg"
    return ICONS / "mingcute" / f"{name.removeprefix('mingcute-')}.svg"


def tinted(name, ink, size):
    """The icon as a pixmap of size, drawn in ink (a "#rrggbb" color)."""
    svg = icon_file(name).read_text().replace("currentColor", ink)
    pixmap = QPixmap(size)
    pixmap.fill(Qt.transparent)
    painter = QPainter(pixmap)
    QSvgRenderer(QByteArray(svg.encode())).render(painter)
    painter.end()
    return pixmap


class IconProvider(QQuickImageProvider):
    """image://icon/<name>?color=rrggbb for QML; `text` when no color is given.

    fallback(name, size) draws names that aren't ours (an app's own icon, say); without one, every
    name is taken as a MingCute icon."""

    def __init__(self, fallback=None, default_size=QSize(32, 32)):
        super().__init__(QQuickImageProvider.Pixmap)
        self.fallback = fallback
        self.default_size = default_size

    def requestPixmap(self, id_, size, requested):
        name, _, query = id_.partition("?")
        px = requested if requested.isValid() and requested.width() > 0 else self.default_size
        if self.fallback and not name.startswith(("mingcute-", "leaves-")):
            return self.fallback(name, px)
        ink = "#" + c if (c := query.removeprefix("color=")) else color("text")
        return tinted(name, ink, px)
