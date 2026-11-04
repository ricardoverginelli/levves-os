# Levves design system

One look for everything: the desktop, the desktop apps, the TV launcher and the suite. It's
direction **D ("Survey")** from the exploration canvas
(https://claude.ai/artifact/9rUWi69F8TpjJwfHkm2pKc): a classic desktop interface built like an
instrument front panel, in Leaves' dark cool grays with one amber accent.

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

The mixes every piece needs are tokens too, in QML: `Theme.hoverTint` (`text` at `opacity.hover`),
`selectionTint`, `edgeLight`, `edgeShade` and `etchLight`; never mix them by hand.

Code names: colors drop their group (`color.text-muted` is `textMuted`), everything else keeps it
(`duration.popup-open` is `durationPopupOpen`). In QML, `on-accent` is `textOnAccent`, since QML reads
`on…` names as signal handlers.

## Mood
- Dark, quiet, cool surroundings. Content and the one accent carry the attention.
- Classic desktop structure: title bars, menu bars, folder-like tabs, group boxes, column headers,
  status bars. Not a modern flat layout of floating cards.
- Built like a panel: things you press are keys, things that show values are sunken readouts,
  sections are framed boxes with a header strip.
- Opaque surfaces only. No blur or glass. The dither texture does what glass used to: it gives
  depth and character, and it's free to draw everywhere.

## Edges: containers vs. controls
The rule that holds the look together:

| | Containers | Controls |
|---|---|---|
| What | Windows, group boxes, lists, readouts, slots, notifications | Keys, tabs, fields, toggles, radios, sliders |
| Outline | 1px `edge` (near black) | 1px `key-edge` / `field-edge` (lighter) |
| Depth | Engraved: an inner 1px light line top-left (white at `opacity.edge-light`) and dark line bottom-right (black at `opacity.edge-shade`) | A key has a 2px `key-depth` bottom edge; pressed, it sinks into `well-pressed` with an inner shadow |
| Corners | `radius.container` (2px) | `radius.key` (3px) |

The black engraved edge never goes on something you press. Group boxes are etched: a 1px `edge`
outline plus a 1px light line (white at `opacity.etch`) offset outside it.

## Color
Neutrals, from darkest: `bg-deep` (desktop), `bg` (top bar, lists), `surface` (windows, cards),
`raised` (keys). Text: `text`, `text-soft` (menus, secondary text on a selection), `text-muted`
(labels), `text-faint` (decoration and disabled only: it fails contrast for reading).

- **Amber is one thing per view**: the primary key, the selection, or the focused window's light.
  - The selected row in the focused window is amber at `opacity.selection`. In every other
    window the selection is neutral `raised`, as classic desktops did.
  - The amber key: `accent` fill, `accent-hover` outline, `accent-edge` bottom edge, `on-accent` text.
- **Status colors** (`critical`, `warning`, `success`, `info`) are for meaning, never decoration.
  As a tag they're text in the color, a fill at `opacity.tag-fill` and an outline at `opacity.tag-edge`.
- Contrast on `bg`: `text` 13.9, `text-muted` 6.6, `accent` 8.3, `critical` 5.3, `warning` 11.7,
  `success` 8.6, `info` 7.2, `on-accent` on `accent` 8.6. All at least 4.5 except `text-faint` (3.3).

## Type
- **Source Serif 4**: window titles, headings, readouts, and every number that gets read (amounts,
  dates, timers, percentages), always with tabular lining figures (`font-variant-numeric:
  tabular-nums lining-nums`). Italic serif for quiet secondary text ("five bills left this month").
- **Source Sans 3**: body text, rows, fields.
- **Caps labels**: Source Sans 3 semibold, uppercase, `type.tracking.label` letter spacing. For
  group headers, column headers, keys, tabs and status bars. The canvas has a switch to try Barlow
  Semi Condensed for them; Source Sans 3 is the default.
- **JetBrains Mono** stays for terminals and code only.
- Sizes are in `type.size`: 11px labels, 14px body on the desktop and 16px on the phone, 15px
  serif titles and inline numbers, 24-28px readouts.

## Pieces
Each piece is built once per platform: CSS classes in `web/levves.css` (`.lv-window`, `.lv-key`...)
and QML types in `qml/` (`WindowFrame`, `TitleBar`, `Key`, `Field`, `Well`, `GroupBox`, `Meter`,
`Tag`, `Slider`, `Led`, `Dither`, and the text styles `Caps`, `Num`, `Title`, `Quiet`), which the build copies
into the `Levves` module. A `flat` key shows only a hover tint until pressed or current (toolbars,
the top bar's window strip).

- **Window**: `surface`, black engraved edge (`WindowFrame`; `docked` draws the edge on the one side
  facing the screen for a window flush against a monitor edge, `bare` none for a maximized one). A 30px title bar (`title-bar`, `title-bar-inactive`
  when unfocused) with a 6px light at the left (amber when focused, `border` otherwise), the serif
  title, and small keys for minimize, maximize and close.
- **Group box**: an etched box with a 24px dithered header strip holding a caps label, and
  optionally a value on the right.
- **Readout**: a `well` with the black edge sunk in, holding a serif number.
- **List**: a `well` with a dithered header row of caps labels, rows separated by `row-line`.
- **Key**: `raised`, `key-edge` outline, 2px `key-depth` bottom edge, a caps label. Pressed or
  current: `well-pressed`, an inner shadow, no bottom edge.
- **Field, toggle, radio**: `well` with a `field-edge` outline and an inner shadow. A toggle is a
  slot with a square knob, `text` when on (right) and `text-faint` when off (left).
- **Meter**: a sunken track with the dither texture and a fill of 10px segments with 2px gaps.
- **Slot**: a 40px sunken square holding a count in serif ("2/4"), dithered when empty.
- **Status bar and menu bar**: a dithered strip with caps labels; the menu bar sits on `surface`.
- **Terminal and code editor**: JetBrains Mono on `bg`, inside a window's chrome (tabs as flat
  keys or folder tabs, a strip under them). ANSI colors are `color.terminal` plus the status colors
  (red `critical`, green `success`, yellow `warning`, blue `info`, white `text`); bright variants
  are the color 25% toward white, faint ones 35% toward `bg`. The amber is the cursor. Built by `os/linux/plasma/yakuake/build.py` (Konsole, Yakuake) and
  `os/linux/plasma/vscode/build.py`.
- **Dither**: a 1px checkerboard of `dither-a` and `dither-b` (`desktop-dither` on the desktop),
  tiled at `size.dither`. Used on group headers, list headers, status bars, disabled keys, empty
  slots and meter tracks.

## Spacing and size
A 4px grid (`space.4` to `space.32`). Title bars 30px (52px headers on the phone), keys 28px, rows
32px on the desktop and 58px on the phone, touch targets at least 44px.

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
- The Plasma style (`plasma-style/build.py`): popups and tooltips as windows on `surface` inside
  the black engraved edge, the top bar on `bg` with an edge along its bottom, and Plasma's own
  controls as keys, wells and slots. Frame pieces must measure whole pixels: lines are filled
  rects, never strokes (`agents/notes/plasma-svg-frames.md`).
- Apps: the color scheme `Levves` (same palette), Source Sans 3 10.5pt for the UI and Source
  Serif 4 11pt semibold for window titles, and the window decoration `kwin-decoration/levves`
  (D's title bar on the Levves pieces). Their widgets are still Breeze's, in Levves colors.
- Bar popups float 4px off the bar with their whole frame (`tray/patches.py`). The top bar is
  28px. A window that spans a whole monitor edge (the side panel, Yakuake) is square and draws
  its edge on the inner side only.
- Exception to "one amber thing": the media popup takes the cover's color
  (`Kirigami.ImageColors`, held at 62-78% lightness, at most 70% saturation) for its visualizer
  and progress meter.

**Motion mechanics** (values in Motion above)
- Plasma's popups and the launcher drop 8px out of their panel with a fade, reversed on close
  (`kwin-effects/leaves-popups`). Panels docked to a monitor edge (Yakuake, the side panel) slide
  all the way in from it on the panel timing, without a fade (`yakuake-slide`, `leaves-popups`).
- Windows moved or resized by KWin glide there on the panel timing (`leaves-geometry`); mouse
  drags never animate.
- What no KWin effect reaches (KWin scripts like snap assist and the cheat sheet, the S25 OSD)
  opens with a 0.96 scale plus a fade in QML, and closes the same way, faster.
- An open bar item gets a 1px accent line along its bottom that grows from the left
  (`shared/ActiveLine.qml`).

**Building a bar widget**
- Show the popup as the applet's `fullRepresentation`: Plasma wraps it in the style's window.
  Don't draw a background or frame, don't set the popup's `margin`, and inset anything drawn edge
  to edge 1px inside the edge.
- Don't animate the popup window (`leaves-popups` does) or draw an open-state line (the tray
  swaps in `ActiveLine`). Open on hover with `shared/HoverOpener.qml` (150ms rest, 400ms grace)
  and no tooltip. Widgets talk over `shared/bus.js`, never by reaching into each other.

**Windows of our own** (a launcher-style `PlasmaCore.Window` or layer-shell window): show and hide
them with `visible` and let `leaves-popups` animate them. Draw them with `WindowFrame`, or the
style's dialog background, and fill them with group boxes and wells.

**Context menus** (reference: `os/linux/media-actions/Menu.qml`)
- At the pointer, below-right, flipped to stay 8px inside the screen; on Wayland a transparent
  layer-shell overlay over the monitor takes the pointer position when it maps (the middle of
  the screen if none arrives within 200ms).
- A 220px Levves window with 4px of padding; rows 32px with a 16px icon in `text-muted`, the
  label in `text`, an optional hint right-aligned in `text-muted`. Hover is `text` at
  `opacity.hover`, the keyboard highlight `accent` at `opacity.selection` (nothing highlighted
  until an arrow key is used).
- Submenus cascade on hover (hover-open rest, 400ms grace), 4px beside the parent, flipped when
  they don't fit. Hide what doesn't apply rather than disabling it; skip a level with one item.
- Keys: Up/Down (Tab), Enter/Space/Right, Left/Backspace back up, Esc closes. Long work reports
  through a notification replaced by its result (`notify-send -p` / `-r`).

## What's still on the old look
- The suite's `packages/design-tokens/tokens.css` keeps a few names that are compositions with no
  Levves token of their own (alert tints, bevel lines, the overlay); everything else reads `--lv-*`.
- Desktop apps' widgets are still drawn by Breeze, in Levves colors, so selections, checkboxes and
  slider fills are solid amber. A Kvantum theme drawn from D's pieces would fix that (to decide;
  `os/linux/plasma/TODO.md`).
