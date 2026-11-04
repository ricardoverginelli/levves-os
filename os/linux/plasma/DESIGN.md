# Design conventions — "Leaves"

Shared look for everything we build or theme on Plasma (panels, widgets, color
scheme, scripts with UI). These are conventions, not hard rules: follow them by
default, and update this file when a decision changes.

The values come from the Levves design system: `design/tokens/` in the repo root, generated into
`design/dist/palette.json`, which the builds here read. The tables below are for reading; to change a
value, change the token and rebuild (`design/DESIGN.md`).

Source wallpaper: `wallpaper/leaves.png` (desktop, lock and login screen; `apply.sh` sets all three) — dark, cool,
blue-green-gray foliage with tiny crimson stem tips.

## Mood
- Dark, quiet, low-contrast surroundings; content and the accent carry attention.
- Neutrals are cool (blue-green gray), never pure black or pure gray.
- The amber accent is used sparingly: one accented thing per view is ideal.
  In lists, that's the keyboard highlight (accent at 18%); hover is a neutral tint
  (text at 6%) and focus rings stay neutral.

## Colors

### Neutrals (from the wallpaper)
| Role | Hex | Use |
|---|---|---|
| `bg-deep` | `#0b1016` | Deepest layer, behind everything (overlays, dimming) |
| `bg` | `#11171d` | Panels, window backgrounds |
| `surface` | `#182027` | Cards, popups, menus |
| `raised` | `#222b32` | Hovered rows, inputs, secondary buttons |
| `border` | `#2e383d` | 1px separators and outlines |
| `text-faint` | `#5f6b67` | Disabled text, decorative only (fails contrast for body text) |
| `text-muted` | `#93a09a` | Labels, secondary text (e.g. "CPU" in the perf meter) |
| `text` | `#dde3df` | Primary text and icons |

### Accent — hiker amber
| Role | Hex | Use |
|---|---|---|
| `accent` | `#e9a23b` | Focus, selection, active state, primary buttons |
| `accent-hover` | `#f3b75c` | Hover on accented elements |
| `accent-pressed` | `#c7852a` | Pressed / held |
| `on-accent` | `#1a1206` | Text and icons on top of `accent` |

Exception, the media popup (`widgets/org.leaves.mediabar`): the cover's color
(`Kirigami.ImageColors` highlight, held at 62-78% lightness and at most 70% saturation) stands in
for the accent there: the sunk screen's visualizer curve and the progress meter's fill.

### Semantic
| Role | Hex | Use |
|---|---|---|
| `critical` | `#e0607a` | Errors, high temps/usage (≥ 85%) — a brighter take on the stem crimson |
| `warning` | `#e8cf6a` | Warnings, elevated temps/usage (≥ 70%) — kept lighter/yellower than the accent so they don't blur together |
| `success` | `#8fbf8a` | OK / done |
| `info` | `#82a9c4` | Neutral information |

### Terminal (ANSI)
Built into the Konsole scheme `Levves` by `yakuake/build.py`. The semantic colors double as
ANSI: red `critical`, green `success`, yellow `warning`, blue `info`, white `text`. The rest:
| Role | Hex |
|---|---|
| `black` | `#222b32` (= `raised`) |
| `bright-black` | `#5f6b67` (= `text-faint`) |
| `magenta` | `#b48cbf` |
| `cyan` | `#7fbab3` |

Bright variants are the color 25% toward white, faint ones 35% toward `bg`. The cursor is
`accent`; the background is `bg` at `glass-opacity` with blur, like any other glass surface.

### Wallpaper references (decorative only)
`leaf` `#353d3f`, `stem` `#7c394d`.

### Contrast (WCAG, against `bg`)
`text` 13.9 · `text-muted` 6.6 · `accent` 8.3 · `critical` 5.3 · `warning` 11.7 ·
`success` 8.6 · `info` 7.2 · `on-accent` on `accent` 8.6. All ≥ 4.5 except
`text-faint` (3.3), which is why it's decorative only.

### Surfaces (Levves: no glass)
Every surface is opaque (design/DESIGN.md Mood). The Plasma style draws panels, popups and
tooltips as D containers (`plasma-style/build.py`): popups and tooltips are windows on `surface`
inside the black engraved edge, the top bar is `bg` with an edge along its bottom. The widgets
drawn in QML are moving over in phases (TODO.md, Levves reskin); until then some still use the
glass fill (`legacy.glass-opacity`).

## Typography
The Levves type (design/DESIGN.md Type), set for all of Plasma and the apps by `apply.sh`:
| Role | Font | Notes |
|---|---|---|
| UI | **Source Sans 3** 10.5pt | Body text, rows, fields (Fedora: `adobe-source-sans-pro-fonts`) |
| Titles, numbers | **Source Serif 4** | Window titles (11pt semibold), the bar's readings, the clock (`adobe-source-serif-pro-fonts`) |
| Labels | Source Sans 3 caps | `Caps` from `import Levves`: 11px semibold, tracked |
| Mono | **JetBrains Mono** | Terminals, code (`jetbrains-mono-fonts`) |

- In QML use the Levves text pieces (`Caps`, `Num`, `Title`, `Quiet`), never a family by name.
- Numbers that update live (clock, meters) use tabular lining figures (`Num` sets them).

## Shape & spacing
- Spacing on a 4px grid: 4, 8, 12, 16, 24, 32. Standard uses:
  | Gap | Where |
  |---|---|
  | 4 | A label and its control (name above a slider), title and body text |
  | 8 | Between rows and cards in a list; icon-less inline items (text and its value) |
  | 12 | Inside a card or row (padding); icon to text; a section's title to its content |
  | 16 | A popup's or panel's content to its edge (the style's frame gives 4, add 12) |
  | 24 | Between sections (with a 1px `border` line in the middle) |
  - Rows with a control (slider, switch) are 40px tall; list rows 36px (44px with two lines).
- Corner radius scales with the element's size: the bigger the container, the rounder, but
  never soft. Pick by the element's shorter side:

  | Element | Shorter side | Radius | Examples |
  |---|---|---|---|
  | Small control | up to 32px | 4px | Buttons, inputs, chips, switches, progress bars |
  | Row or card | 32-120px | 6px | List rows, cards inside a popup, thumbnails, cover art, tooltips |
  | Floating surface | over 120px | 8px | Bar popups, menus, the launcher, OSDs, snap assist, dialogs |
  | Edge to edge | spans a whole monitor edge | 0 | The top bar, Yakuake, the side panel |

  - Nested shapes: an inner shape's radius is the outer one minus the padding between them,
    never below 4px (a 6px card inside an 8px popup with 4px of padding stays 4px).
  - Pills are the exception: a round toggle or badge uses half its height.
  - The Plasma style draws every popup's frame and blur mask at 8px (`popup-radius` in `palette.json`).
    Every piece of that frame must measure whole pixels (8px corners, 32px edges): lines in it are
    filled shapes, never strokes, since Qt counts a stroke's width into the piece's size. Fractional
    pieces showed as see-through squares where corners meet edges and tick marks along the edges.
    Check with `QSvgRenderer.boundsOnElement` (see `agents/notes/plasma-svg-frames.md`).
- Edges: every floating surface is a Levves window, inside the black engraved edge (popups, the
  launcher, the side panel), drawn by the Plasma style for Plasma's popups and by `WindowFrame`
  for QML windows. Inside, sections are group boxes and wells (design/DESIGN.md Edges).
- Bar popups float 4px off the bar with their whole frame (all four corners rounded and
  bordered), so they read as floating rather than glued to it. The tray sets this for its own
  popup and every panel widget's (`tray/patches.py`).
- Top bar: 28px tall.

- Controls drawn in QML (the side panel, the cheat sheet), so they match wherever they appear:
  - Slider: 4px `raised` track, fill in `text-muted` (`text-faint` when muted), 12px round
    handle in `text-muted`, `text` on hover and `accent` while dragged (the one accent).
  - Segmented tabs: a `raised` track with 2px of padding, the current tab on `surface`; labels
    `text-muted`, `text` when current or hovered.
  - Keycap: 24px tall, 4px corners, `raised` fill with a 1px `border`, JetBrains Mono 9pt in
    `text`; Meta is drawn as the Leaves leaf. Keys in a combo are joined by a `text-faint` "+".

## Icons
- Library: **MingCute** (https://www.mingcute.com/, Apache-2.0), **Fill** style by default.
  The Line style is only for a deliberate secondary/inactive state of the same icon.
- Monochrome: icons are drawn as masks in a text token (`Kirigami.Icon { isMask: true }`),
  never in their own colors. App icons (Spotify, Brave…) stay as the apps ship them, except
  where one clashes in a small spot: notification headers swap Spectacle's for MingCute's
  `screenshot` in `text-muted` (`leavesAppIcons` in `notifications/patches.py`).
- Sizes: 16px in the bar, rows and buttons; 24px where an icon stands in for an app.
- Adding one: put its name in `icons/mingcute.txt`, run `icons/fetch.py`, commit the SVG.
  `apply.sh` installs it as `mingcute-<name>`, e.g. `source: "mingcute-play-fill"`.
- Gaps: when MingCute has nothing that reads at 16px, draw one in its style (24px grid,
  filled, rounded 1-3px corners) in `icons/custom/`; it installs as `leaves-<name>`.
  So far: `cpu` (MingCute's chip reads as a gear at 16px), `ram` (a memory stick),
  `leaf` (the launcher) and `log-out`. Draw with `currentColor`, never a fixed color:
  `icons/install.py` adds KDE's recoloring hooks so the icons take the theme's text color.

## Motion
- House curve: **OutQuint** — fast start, soft landing. It's a named curve, so KWin effects
  (which take only named curves) and QML use exactly the same one.
  - QML: `easing.type: Easing.OutQuint`
  - KWin: `curve: QEasingCurve.OutQuint`
  - CSS: `cubic-bezier(0.2, 0.8, 0.2, 1)` (the old house bezier; within 0.024 of OutQuint)
- Durations (the "Relaxed" set; closing is ~30% faster, same curve):

  | Token | Open | Close | Used for |
  |---|---|---|---|
  | hover | 150ms | 150ms | Hover/press tints |
  | popup | 240ms | 170ms | Bar popups, the launcher, OSDs |
  | panel | 320ms | 220ms | Large panels and overlays: Yakuake |
  | hover-open | 150ms | 400ms | Rest before a hovered bar item opens / grace before it closes |

- Popups open out of their panel ("Drop"): an 8px slide from the panel's edge plus a fade,
  reversed on close. The KWin effect `kwin-effects/leaves-popups` does it for Plasma's popups
  and the launcher (from the top bar), glass included. Snap assist, the Alt+Tab switcher and the S25 OSD
  aren't Plasma windows; they open with a 0.96 scale plus the fade in QML.
- Windows moved or resized by KWin (tiling, maximize, another monitor) glide there on the panel
  timing (`kwin-effects/leaves-geometry`); mouse drags never animate.
- Panels docked to a monitor edge (Yakuake, the side panel) slide all the way in from that
  edge on the panel timing, without a fade (`yakuake-slide`, `leaves-popups`).
- An open bar item is marked by a 1px accent line along its bottom that grows from left to
  right on popup timing and fades on close (`shared/ActiveLine.qml`): tray items, the perf
  meter's Wi-Fi reading, and every panel widget (clock, media bar), which the tray restyles.
- No bounce/overshoot.

## Building a widget or window
A checklist of what the shared pieces already do, so a new one fits in without redoing it.

**Bar widgets (panel applets in the top bar)**
- Show the popup as the applet's `fullRepresentation`; Plasma wraps it in its popup window.
  Don't draw a window background or your own frame: the Plasma style draws the glass, the
  8px corners and the 1px border, and the tray floats the popup 4px off the bar with its whole
  frame (`tray/patches.py`). Don't set the popup's `margin` or `removeBorderStrategy`.
- Anything painted edge to edge inside the popup (a backdrop, cover art) stays inside the
  border: inset it 1px on all four sides and round it at 7px (8 minus the border).
- Don't animate the popup window: `kwin-effects/leaves-popups` drops it out of the bar.
  Animate only what changes inside it, with the Motion tokens.
- Don't draw an open-state line: the tray swaps the panel's for the growing `ActiveLine`.
  A reading that opens a popup some other way (like the perf meter's Wi-Fi reading) adds
  `ActiveLine { active: … }` itself.
- Opening on hover: `HoverOpener` (`shared/`, 150ms rest, 400ms grace, instant switch while
  another popup is open), and no tooltip on that item, since it would cover the popup.
- Widgets in one bar talk over `shared/bus.js`, never by reaching into each other's items.

**Windows of our own** (launcher-style `PlasmaCore.Window`, layer shell)
- Undecorated plasmashell windows are animated by `leaves-popups`: a free one drops 8px from
  the top bar with a fade, one flush against a monitor edge slides in from that edge. Show and
  hide them with `visible`, at full opacity, with no QML open/close animation.
- Use the style's dialog background for the glass, the 8px frame and the border. A window that
  spans a whole monitor edge (the side panel) has radius 0 and draws its 1px border on the
  inner side only.

**Anything that isn't a Plasma window** (KWin declarative scripts like snap assist or the
cheat sheet, the S25 app)
- No KWin effect reaches it: open with a 0.96 scale plus a fade (popup timing, OutQuint) and
  close the same way, faster.

**Context menus** (our own menus, opened by a click; reference: `../media-actions/Menu.qml`,
whose `MenuCard` component is the one to copy)
- Placement: at the pointer, below-right of it, flipped left/up to stay 8px inside the
  screen. On Wayland a client can't read the pointer, so the menu is a transparent layer-shell
  overlay over the monitor (`ScreenFromCompositor`, exclusive keyboard) that takes the pointer
  position when it maps; the middle of the screen if none arrives within 200ms.
- Card: 220px wide, `surface` fill, 8px radius, 1px `border`, 4px padding. Rows 36px with 4px
  corners: 16px icon in `text-muted`, 12px from the edge and from the label; label `text` 10pt;
  an optional hint right-aligned in `text-muted` 9pt (what the item does or uses, e.g.
  "LosslessCut", "Audio only").
- States: hover is `text` at 6%, the keyboard highlight `accent` at 18%. Nothing is
  highlighted until an arrow key is used; hovering a row clears the keyboard highlight.
- Submenus cascade on hover: the parent row ends in a `right-fill` chevron (`left-fill` when
  the submenu flips). It opens after the hover-open rest (150ms) and closes 400ms after the
  pointer rests on a sibling row, so a diagonal trip toward it doesn't close it; reaching the
  submenu cancels that. Clicking the row opens it at once. The submenu sits 4px beside the
  parent card with its first row level with the parent row, flips to the left side when it
  doesn't fit, and is clamped to the screen. The parent row keeps the hover tint while it's open.
- Contents fit the target: hide what doesn't apply (no "convert to MP4" on an MP4, no Cut for
  images) rather than disabling it. If only one top-level item would be left, skip that level
  and show its contents as the menu.
- Keyboard: Up/Down (Tab/Shift+Tab) move, Enter/Space/Right activate or open a submenu, Left
  or Backspace go back up, Esc closes.
- Dismiss: a click outside or Esc. Menu and submenu fade out together (the close half of the
  0.96 scale + fade), and the chosen action runs once they're gone.
- Long work started from a menu reports through a notification: a "…ing" one replaced by
  the result (`notify-send -p` / `-r`), with an action to reveal the output when there is one.

**Every time**
- Radius by the shorter side (Shape & spacing), spacing on the 4px grid with its standard gaps,
  colors only from the palette, MingCute Fill icons as masks, Noto Sans at the listed sizes.
- Motion only with the house curve and the duration tokens; no bounce.
- Glass for anything floating over other content; one accented thing per view.
