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

### Wallpaper references (decorative only)
`leaf` `#353d3f`, `stem` `#7c394d`.

### Contrast (WCAG, against `bg`)
`text` 13.9 · `text-muted` 6.6 · `accent` 8.3 · `critical` 5.3 · `warning` 11.7 ·
`success` 8.6 · `info` 7.2 · `on-accent` on `accent` 8.6. All ≥ 4.5 except
`text-faint` (3.3), which is why it's decorative only.

### Translucency
Panels: `bg` at 65% opacity with KWin blur behind (glass). Popups: `surface`, opaque or ~95%.

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
- Corner radius: 8px small (buttons, rows, inputs), 12px large (popups, cards).
- Borders: 1px `border`, only where surfaces of similar tone meet.
- Top bar: 28px tall.

## Motion
- House curve: **`cubic-bezier(0.2, 0.8, 0.2, 1)`** — fast start, soft landing.
  - QML: `easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1]`
  - KWin effects only accept named curves; nearest is `QEasingCurve.OutCubic`.
- Durations: 120ms hover/press, 200ms popups opening, 280ms large panels/overlays.
- Closing uses the same curve ~30% faster (e.g. popup closes in 140ms).
- No bounce/overshoot.
