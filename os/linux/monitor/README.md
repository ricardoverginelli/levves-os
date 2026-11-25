# monitor

`Meta+Shift+M` turns the main monitor off and back on. Use it to hand the
monitor to another device: turn it off here, then switch the monitor's input.

## Install

```bash
bash install.sh              # bash install.sh --uninstall to undo
```

`install.sh` links `main-monitor` into `~/.local/bin`, adds a hidden launcher
(`~/.local/share/applications/main-monitor-toggle.desktop`), and binds it
through kglobalaccel.

## How it works

- **Off:** finds the primary output (lowest kscreen priority), saves its name,
  mode and position to `~/.local/state/main-monitor`, and disables it with
  `kscreen-doctor`. Won't turn off the only enabled screen.
- **On:** re-enables the saved output with that mode and position, and makes
  it primary again. With no saved state (turned off in System Settings, or
  the file is gone), it turns on the first connected but disabled external
  screen instead, at the mode and position kscreen remembers.
- No connector name is hardcoded, so it still works when names change after a
  GPU swap.
- `main-monitor off` / `main-monitor on` force one or the other.
