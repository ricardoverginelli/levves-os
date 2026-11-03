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
| QML (desktop apps) | `dist/qml/Levves/` | `engine.addImportPath(<repo>/design/dist/qml)`, `import Levves`, then `Theme.accent` |
| Compose (TV launcher) | `dist/kotlin/Levves.kt` | `Levves.accent` |
| Python builds | `dist/levves_tokens.py`, `dist/palette.json` | `TOKENS["color.accent"]` |
| Android XML | `dist/android/res/` | `@color/levves_accent` |

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
- **Window**: `surface`, black engraved edge. A 30px title bar (`title-bar`, `title-bar-inactive`
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
MingCute, Fill style, drawn as masks in a text color. Details in `os/linux/plasma/DESIGN.md`
until the icon set moves here.

## What's still on the old look
Until the reskin, Plasma keeps its glass (`legacy.*` tokens) and the suite keeps its Win95 tokens
in `packages/design-tokens/`. `os/linux/plasma/DESIGN.md` still describes Plasma-specific
mechanics (popup frames, KWin effects, menus); its colors and motion come from here.
