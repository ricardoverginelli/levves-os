# Plasma frame SVGs: squares at the corners, rulers on the edges

Symptom: a Plasma style frame (`dialogs/background`, any FrameSvg) shows see-through squares
right where each rounded corner meets an edge, and faint tick marks every 32px along the edges.
The squares are fully transparent (no fill, blur or border), so they read as holes over a bright
window and are easy to miss over a dark one.

Cause: KSvg lays the frame out from each piece's bounds as Qt's SVG renderer reports them, and
Qt counts a stroke's width into those bounds. A corner drawn as an 8px fill plus a 1px stroked
arc measures 8.5px, a 32px edge measures 33px, and the pieces no longer meet.

- Draw lines inside frame pieces as filled shapes: a 1px rect on edges, a quarter ring
  (outer radius r, inner r-1) in corners. `plasma-style/build.py` `frame_svg()` does this.
- Check the bounds without restarting plasmashell (PySide6 uses the system Qt):
  `QSvgRenderer(svg).transformForElement(id).mapRect(r.boundsOnElement(id))` must give whole
  numbers for every piece.
- Or render the frame offscreen with KSvg itself: a `KSvg.FrameSvgItem` with an absolute
  `imagePath` in a `QQuickView` under `QT_QPA_PLATFORM=offscreen`, over a magenta background,
  then look for magenta pixels inside the frame.
- `hint-stretch-borders` (stretch edge pieces instead of tiling them) hides the edge seams
  but not the corner holes. Don't add `mask-hint-stretch-borders`: it broke the blur mask.
- After changing the style, clear `~/.cache/plasma_theme_leaves.kcache` and
  `~/.cache/ksvg-elements`, then restart plasmashell. Space the restarts out: a few in quick
  succession hit systemd's start limit (`systemctl --user reset-failed plasma-plasmashell`).

Seen 2026-10-25 on every popup since the 8px bordered frame (dee6755).
