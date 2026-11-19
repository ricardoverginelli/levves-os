# Levves design system

One look for everything: the desktop, the desktop apps, the TV launcher and the suite. It's
**Urban Flora**, drawn from the wallpaper of the same name (`os/linux/plasma/wallpaper/urban-flora.png`):
a city overgrown by forest at night, built from flat planes that get lighter with distance, a
glowing teal fog, and a few amber lit windows. The exploration and the chosen direction
("Skyline", C's structure with B's light) are on the canvas
(https://claude.ai/artifact/LQTWMQVjK7p63Tb6ZthMfL). It replaced direction D, "Survey", on
2026-11-18.

The values live in `tokens/*.json` (W3C DTCG). Never copy a value into an app: use the generated
file for its platform from `dist/`, and rebuild after changing a token:

```
python3 design/build/build.py          # writes dist/
python3 design/build/build.py --check  # what CI runs, with check_hardcoded.py: no color copied by hand
```

| Platform | File | Use |
|---|---|---|
| Web (suite, p45 editor) | `dist/tokens.css` | `var(--lv-color-accent)` |
| QML (desktop apps, Plasma) | `dist/qml/Levves/` | `engine.addImportPath(<repo>/design/dist/qml)` (Plasma: `QML_IMPORT_PATH`, set by `os/linux/plasma/apply.sh`), `import Levves`, then `Theme.accent` and the pieces below |
| Web pieces | `web/levves.css` | `.lv-window`, `.lv-key`, ... |
| Compose (TV launcher) | `dist/kotlin/Levves.kt` | `Levves.accent` |
| Python (builds, desktop apps) | `dist/levves_tokens.py`, `dist/levves_qt.py` | `design/dist` on `sys.path`, then `color("accent")`; `levves_qt.tinted()` and `IconProvider` for MingCute icons in a token color |
| Android XML | `dist/android/res/` | `@color/levves_accent` |
| Fonts | `fonts/` | Figtree and Bricolage Grotesque (OFL, from google/fonts); `os/linux/plasma/apply.sh` installs them |

The mixes every piece needs are tokens too, in QML: `Theme.hoverTint` (`text` at `opacity.hover`)
and `selectionTint` (`fog` at `opacity.selection`); never mix them by hand.

Code names: colors drop their group (`color.text-muted` is `textMuted`), everything else keeps it
(`duration.popup-open` is `durationPopupOpen`). In QML, `on-accent` is `textOnAccent`, since QML reads
`on…` names as signal handlers.

## Mood
- Dark, quiet, teal-black surroundings, like the city at night. Content and the one amber light
  carry the attention.
- **Flat shading.** Shapes meet without outlines or bevels; depth is value. Nearer planes are
  darker, farther ones lighter and closer to the fog. No textures, no dither, no inner shadows.
- **Hi-tech structure.** Square corners, hairlines inside a window (never around content), lit-cell
  meters, tabular numbers. Compact: no chrome that carries nothing (no status bar for show).
- **Light has a source.** Frosted shell panes are lit by a soft pool of fog from their top-right
  corner, never a plain linear gradient. The only glow is the primary key's.

## Surfaces
The rule that holds the look together:

| | Shell panes | App windows | Inside a window |
|---|---|---|---|
| What | Top bar, popups, notifications, menus, the launcher, OSDs, the terminal | Dolphin, the suite, our desktop apps: anything Plasma can't blur | Content areas, lists, fields, keys |
| Fill | Frosted: blurred, `surface` (or `bg` for bar and terminal) at `opacity.pane` / `bar` / `terminal`, lamp light from the top-right at `opacity.lamp` | Solid `surface`; title plane `title-bar` (`title-bar-inactive` unfocused) | Flat planes: `well` for content, `raised` for keys, `bg-deep` for fields |
| Border | 1px `edge` (fog at `opacity.outline`) on every side that doesn't touch a screen edge | The same `edge` | None around content; 1px `border` hairlines between areas |
| Corner | Top-right cut by `cut.pane` (12px); no cut when that corner touches a screen edge (docked panels) | Top-right cut by `cut.window` (18px); none when maximized or snapped into that corner | Square |

- **The cut is always top-right.** If the top-right corner can't be cut (it touches a screen edge,
  or the surface is docked there), the surface has no cut at all: never move it to another corner.
- **Frosted or solid, nothing in between.** When a surface can't be blurred, it's solid; never
  translucent without blur.
- Anything that floats or needs to lift off what's behind it gets the weak `edge` border, so it
  never blends into the wallpaper.

## Color
Planes, nearest to farthest: `bg-deep` (desktop, fields), `bg` (top bar, content, terminal),
`surface` (windows, panes), `raised` (title planes, keys, the selected row). `border` for hairlines.
Text: `text`, `text-soft`, `text-muted` (labels), `text-faint` (decoration and disabled only: it
fails contrast for reading).

- **Fog** is the cool light: `fog` for focus, the current tab or pane (a 2px line), the selected
  row's line, meter fills, info; `fog-deep` for what's unlit; `glow` for the rare highlight.
- **Amber is one thing per view: the primary key.** A lit window: `accent` fill, `on-accent` text,
  and the view's only glow (amber at `opacity.key-glow`, 18-20px). Also the terminal's cursor and
  prompt.
- **Selection** is `raised` with a 2px `fog` line at the left, or `selectionTint` over a plane that's
  already `raised`. Hover is `hoverTint`.
- **Status colors** (`critical`, `warning`, `success`, `info`) are for meaning, never decoration.
  As a tag: text in the color, semibold, on a plane of the color at `opacity.tag-fill`; no outline.
- `decorative.stem` (the wallpaper's red stems) is for illustration only; it's too dark to read.
- Contrast on `bg`: `text` 15.0, `text-soft` 11.5, `text-muted` 7.4, `fog` 8.2, `accent` 9.0,
  `critical` 6.7, `warning` 12.1, `success` 9.3, `on-accent` on `accent` 8.9. All at least 4.5
  except `text-faint` (3.6).

## Type
- **Bricolage Grotesque** (`type.family.display`): window and pane titles, headings and readout
  numbers. Semibold (650 where the weight is free), `type.tracking.display`.
- **Figtree** (`type.family.sans`): everything else: body text, rows, fields, keys, labels and every
  inline number, always with tabular lining figures (`font-variant-numeric: tabular-nums
  lining-nums`). Body at `type.weight.body` (450), a touch heavier for reading on dark.
- **Labels are sentence case**, `type.size.label` semibold in `text-muted`. No uppercase labels,
  no letter spacing.
- **JetBrains Mono** for terminals and code only. The Leaves launcher is drawn like the terminal
  launcher (`agents/launcher`): all mono, one flat surface, lines only between its areas and
  inside its task table.
- Sizes are in `type.size`: 12px labels, 13px body on the desktop and 16px on the phone, 14px
  titles, 22-28px readouts. No serif anywhere (`type.family.serif` is a deprecated alias of display).

## Pieces
Each piece is built once per platform: CSS classes in `web/levves.css` (`.lv-window`, `.lv-key`...)
and QML types in `qml/` (`WindowFrame`, `TitleBar`, `Key`, `Field`, `Well`, `GroupBox`, `Meter`,
`Tag`, `Slider`, and the text styles `Caps`, `Num`, `Title`, `Quiet`), which the build copies into
the `Levves` module. Pieces still being redrawn from Survey are listed at the end.

- **Window**: solid `surface`, `edge` border, top-right cut. A 30px title plane: the display title
  (and `/ section` in `text-muted`), live info that used to sit in a status bar (sync time), and
  small square keys for minimize, maximize and close. No light at the left.
- **Tabs**: flat segments under the title plane; the current one is `well` with a 2px `fog` line on
  top, the others text in `text-muted`.
- **Content**: a `well` area inset 16px from the window's sides; its areas are split by `border`
  hairlines, not boxes.
- **Section** (was group box): a sentence-case label over its content, separated from the next
  section by a hairline. No frame, no header strip.
- **Readout**: a label, a display number, and optionally a tick scale under it in `fog` (lit) and
  `fog-deep` (unlit).
- **List**: on `well`, a header row of labels with a hairline under it, rows 32px separated by
  `row-line`; the selected row is `raised` with a 2px `fog` line at the left.
- **Bottom bar**: a window's actions sit flush in a 36px bar along the bottom of its content, with a
  hairline above: the field fills the left, then keys, then the primary key at the far right.
  Nothing floats.
- **Key**: square, `raised` (one step lighter than what it sits on), the label in sans. Pressed or
  current: `well-pressed`. Primary: amber with its glow. A `flat` key shows only `hoverTint` until
  pressed or current (toolbars, the top bar's window strip).
- **Field**: an opening: `bg-deep`, a 1px `field-edge` outline, an optional leading icon in
  `text-muted`. Focused, the outline is `fog`. Disabled, no outline and `text-faint` text. No
  shortcut chips inside fields.
- **Toggle**: a square `raised` slot with a square knob, `fog` when on (right), `text-faint` off.
- **Meter**: a row of lit cells, like the towers' windows: `fog` cells (lit) and `raised` cells
  (unlit), 2-3px gaps. A small bar meter is 3px-wide cells.
- **Slider**: a 6px `raised` track with a `fog` fill (`fog-deep` when it isn't the current one).
- **Terminal and code editor**: JetBrains Mono on frosted `bg`, tabs as flat segments with the fog
  line, and the focused pane marked by a 2px `fog` line on top. ANSI colors are `color.terminal`
  plus the status colors (red `critical`, green `success`, yellow `warning`, blue `info`, white
  `text`); bright variants are the color 25% toward white, faint ones 35% toward `bg`. Amber is the
  cursor and the prompt. Built by `os/linux/plasma/yakuake/build.py` (Konsole, Yakuake) and
  `os/linux/plasma/vscode/build.py`.

## Spacing and size
A 4px grid (`space.4` to `space.32`). Top bar 26px, title planes 30px (52px headers on the phone),
tabs 28px, keys and fields 30px, bottom bars 36px, rows 32px on the desktop and 58px on the phone,
touch targets at least 44px.

## Motion
One curve, `easing.out-quint` (Qt and KWin have it built in as OutQuint). Durations in `duration.*`:
150ms for hover, 240/170ms for popups opening/closing, 320/220ms for large panels. Closing is about
30% faster than opening. No bounce or overshoot.

## Icons
- Library: **MingCute** (https://www.mingcute.com/, Apache-2.0), **Fill** style by default; the
  Line style only for a deliberate secondary state of the same icon.
- Monochrome: drawn as masks in a text color (`Kirigami.Icon { isMask: true }`), never in their own
  colors. App icons stay as the apps ship them, except where one clashes in a small spot
  (notification headers swap Spectacle's for MingCute's `screenshot`, `leavesAppIcons` in
  `os/linux/plasma/notifications/patches.py`).
- Sizes: 16px in the bar, rows and keys; 24px where an icon stands in for an app.
- Adding one: its name in `os/linux/plasma/icons/mingcute.txt`, run `icons/fetch.py`, commit the
  SVG; `apply.sh` installs it as `mingcute-<name>`. When MingCute has nothing that reads at 16px,
  draw one in its style (24px grid, filled, `currentColor`) in `icons/custom/`; it installs as
  `leaves-<name>` (so far `cpu`, `ram`, `leaf`, `log-out`).

## Desktop (Plasma)
Everything under `os/linux/plasma/`, applied by its `apply.sh`; phases in its `TODO.md`.

**Where each part is drawn**
- The Plasma style (`plasma-style/build.py`): popups, tooltips and notifications as frosted panes
  (KWin's blur behind a translucent `surface`, the lamp light, the `edge` border, the 12px cut),
  the top bar frosted on `bg` with a hairline along its bottom, and Plasma's own controls as flat
  keys, fields and meters. Frame pieces must measure whole pixels: lines are filled rects, never
  strokes (`agents/notes/plasma-svg-frames.md`).
- Apps: the color scheme `Levves` (same palette), Figtree for the UI and Bricolage Grotesque for
  window titles, and the window decoration `kwin-decoration/levves` (the solid title plane, the
  `edge` border and the 18px cut). Their widgets are still Breeze's, in Levves colors.
- Bar popups float 4px off the bar with their whole frame (`tray/patches.py`). The top bar is
  26px. A window that spans a whole monitor edge (the side panel, Yakuake) is square, has no cut,
  and draws its `edge` on the inner side only.
- Exception to "one amber thing": the media popup takes the cover's color
  (`Kirigami.ImageColors`, held at 62-78% lightness, at most 70% saturation) for its visualizer
  and progress meter. The Leaves Music dock goes further: the cover's color on its toggles, slider
  and play key (a primary `Key` with `tone`), and the cover itself behind everything, blurred
  (`CoverBackdrop.qml`), because a player should look like what it plays.

**Motion mechanics** (values in Motion above)
- Plasma's popups and the launcher drop 8px out of their panel with a fade, reversed on close
  (`kwin-effects/leaves-popups`). Panels docked to a monitor edge (Yakuake, the side panel) slide
  all the way in from it on the panel timing, without a fade (`yakuake-slide`, `leaves-popups`).
- Windows moved or resized by KWin glide there on the panel timing (`leaves-geometry`); mouse
  drags never animate.
- What no KWin effect reaches (KWin scripts like snap assist and the cheat sheet, the S25 OSD)
  opens with a 0.96 scale (`scale.appear`) plus a fade in QML, and closes the same way, faster:
  the Levves `Appear` piece, or `AppearIn` / `AppearOut` as a Popup's or a list's transitions.
- An open bar item gets a 2px `fog` line along its bottom that grows from the left
  (`shared/ActiveLine.qml`).

**Building a bar widget**
- Show the popup as the applet's `fullRepresentation`: Plasma wraps it in the style's pane.
  Don't draw a background or frame, don't set the popup's `margin`, and inset anything drawn edge
  to edge 1px inside the border.
- Don't animate the popup window (`leaves-popups` does) or draw an open-state line (the tray
  swaps in `ActiveLine`). Open on hover with `shared/HoverOpener.qml` (150ms rest, 400ms grace)
  and no tooltip. Widgets talk over `shared/bus.js`, never by reaching into each other.

**Windows of our own** (a launcher-style `PlasmaCore.Window` or layer-shell window): show and hide
them with `visible` and let `leaves-popups` animate them. Draw them as frosted panes (the style's
dialog background, or `WindowFrame` with `pane: true`) and fill them with sections, wells and
lists.

**Context menus** (reference: `os/linux/media-actions/Menu.qml`)
- At the pointer, below-right, flipped to stay 8px inside the screen; on Wayland a transparent
  layer-shell overlay over the monitor takes the pointer position when it maps (the middle of
  the screen if none arrives within 200ms).
- A 220px frosted pane with 4px of padding; rows 32px with a 16px icon in `text-muted`, the
  label in `text`, an optional hint right-aligned in `text-muted`. Hover is `hoverTint`, the
  keyboard highlight `raised` with the 2px `fog` line (nothing highlighted until an arrow key is
  used).
- Submenus cascade on hover (hover-open rest, 400ms grace), 4px beside the parent, flipped when
  they don't fit. Hide what doesn't apply rather than disabling it; skip a level with one item.
- Keys: Up/Down (Tab), Enter/Space/Right, Left/Backspace back up, Esc closes. Long work reports
  through a notification replaced by its result (`notify-send -p` / `-r`).

## Moving off Survey
The tokens switched first: Survey's names that the code still reads have flat values now
(`dither-b` equals `dither-a`, `key-depth` and `key-edge` equal `raised`, `edge-light`, `edge-shade`
and `etch` are zero, `edge` is the weak border, `type.family.serif` points at display), so
everything already draws flat. Marked "Deprecated" in `tokens/`, they go once nothing reads them.
Still to redraw (order in `os/linux/plasma/TODO.md`):
- The pieces: `GroupBox` becomes a section, `Dither` and `Led` go, `Caps` becomes the
  sentence-case label, `WindowFrame` gains the cut, the border and the frosted `pane` mode,
  `Meter` becomes lit cells, `web/levves.css` to match.
- The desktop: Plasma style SVGs (frosted panes, cut, lamp), the decoration, the color scheme
  and fonts, Yakuake/Konsole and VS Code.
- The apps, one at a time; the TV launcher last.
- The suite's `packages/design-tokens/tokens.css` keeps a few names that are compositions with no
  Levves token of their own (alert tints, bevel lines, the overlay).
