# Design conventions — "Leaves"

Shared look for everything we build or theme on Plasma (panels, widgets, color
scheme, scripts with UI). These are conventions, not hard rules: follow them by
default, and update this file when a decision changes.

Machine-readable values live in `palette.json` (used by `plasma-style/build.py`);
keep it in sync with the tables below.

Source wallpaper: `~/Pictures/leaves_2560x1440_sharp2.png` — dark, cool,
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

### Semantic
| Role | Hex | Use |
|---|---|---|
| `critical` | `#e0607a` | Errors, high temps/usage (≥ 85%) — a brighter take on the stem crimson |
| `warning` | `#e8cf6a` | Warnings, elevated temps/usage (≥ 70%) — kept lighter/yellower than the accent so they don't blur together |
| `success` | `#8fbf8a` | OK / done |
| `info` | `#82a9c4` | Neutral information |

### Terminal (ANSI)
Built into the Konsole scheme `Leaves` by `yakuake/build.py`. The semantic colors double as
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

### Translucency
Glass is the default for every surface that floats over other content: a
translucent fill with KWin's blur behind it. The Plasma style applies it to all
panels, popups and tooltips (`plasma-style/build.py`); custom windows get it by
using the style's background (`PlasmaCore.Window`/`Dialog`), never an opaque
`Rectangle`.
- Fill: `bg` at 40% opacity (`glass-opacity`), the same for panels, popups, the launcher and tooltips.
  Kept low on purpose: the blur flattens what's behind into one tone, so a denser fill reads as solid.

## Typography
| Role | Font | Notes |
|---|---|---|
| UI | **Noto Sans** | Everything in panels, widgets, apps (package `google-noto-sans-fonts`) |
| Mono | **JetBrains Mono** | Terminals, code, numeric readouts that must align (package `jetbrains-mono-fonts`) |

- Sizes: 10pt default UI, 9pt for dense readouts (perf meter), 11pt for titles.
- Weights: Regular for content, Medium/Bold only for emphasis (e.g. the clock).
- Numbers that update live (clock, meters) use tabular figures so they don't
  jiggle; Noto Sans digits are tabular by default.

## Shape & spacing
- Spacing on a 4px grid: 4, 8, 12, 16, 24, 32.
- Corner radius: 8px small (buttons, rows, inputs), 12px large (popups, cards). The Plasma
  style draws every popup's frame and blur mask at 12px (`popup-radius` in `palette.json`).
- Borders: 1px `border`, only where surfaces of similar tone meet.
- Top bar: 28px tall.

## Icons
- Library: **MingCute** (https://www.mingcute.com/, Apache-2.0), **Fill** style by default.
  The Line style is only for a deliberate secondary/inactive state of the same icon.
- Monochrome: icons are drawn as masks in a text token (`Kirigami.Icon { isMask: true }`),
  never in their own colors. App icons (Spotify, Brave…) stay as the apps ship them.
- Sizes: 16px in the bar, rows and buttons; 24px where an icon stands in for an app.
- Adding one: put its name in `icons/mingcute.txt`, run `icons/fetch.py`, commit the SVG.
  `apply.sh` installs it as `mingcute-<name>`, e.g. `source: "mingcute-play-fill"`.
- Gaps: when MingCute has nothing that reads at 16px, draw one in its style (24px grid,
  filled, rounded 1-3px corners) in `icons/custom/`; it installs as `leaves-<name>`.
  So far: `cpu` (MingCute's chip reads as a gear at 16px), `ram` (a memory stick),
  `leaf` (the launcher) and `log-out`. Draw with `currentColor`, never a fixed color:
  `icons/install.py` adds KDE's recoloring hooks so the icons take the theme's text color.

## Motion
- House curve: **`cubic-bezier(0.2, 0.8, 0.2, 1)`** — fast start, soft landing.
  - QML: `easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1]`
  - KWin effects only accept named curves; nearest is `QEasingCurve.OutCubic`.
- Durations: 120ms hover/press, 200ms popups opening, 280ms large panels/overlays.
- Closing uses the same curve ~30% faster (e.g. popup closes in 140ms).
- No bounce/overshoot.
