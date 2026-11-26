# QML effects drawing blank: software renderer

If a QML `layer.effect`, mask or shader draws nothing, check whether Qt Quick is running on the
software renderer, which can't draw shader effects. Nothing shows up as a QML error.

- Check `~/.config/kdeglobals` for `[QtQuickRendererSettings] SceneGraphBackend=software`. The KDE
  platform theme applies it to every Qt Quick app, plasmashell included.
- Confirm it with `QT_LOGGING_RULES=qt.scenegraph.general=true`: the journal says "Loading backend
  software" instead of "Creating QRhi with backend OpenGL".
- Fix: remove those lines, then `systemctl --user restart plasma-plasmashell`.

Seen 2026-10-19 on the desktop (origin unknown, not set by hand): the Leaves launcher's list went
blank whenever it could scroll, because that's when its fade mask switches on.
