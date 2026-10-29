# scripts

Personal machine setup and automation scripts. Windows setup lives in `windows/`, Linux setup in
`linux/`; each has one folder per component. This file covers `windows/`. It's used to bootstrap a
new machine or reinstall individual tools granularly.

## Repo Structure

```
scripts/windows/
  setup.py              ← Master orchestrator, runs selected components interactively
  vscode/install.py     ← Installs VS Code extensions
  sharex/
    install.py          ← Installs ShareX and imports backup config
    ShareX-*.sxb        ← ShareX backup config (exported from Application Settings → Export)
  ahk/
    install.py          ← Installs AutoHotkey v2 and registers gmk104.ahk on startup
    gmk104.ahk          ← AHK v2 keyboard remap, Windows port of linux/keyd/gmk104.conf
  theme/install.py      ← Applies the Leaves look (from linux/plasma/) to Windows
  updates/
    install.py          ← Turns Windows Update off and keeps it off at every boot (admin)
    disable-updates.ps1 ← The policy/service/task changes; also what the startup task runs
  gmk104-image-tool/    ← Vendor tool for the GMK104's screen, plus the edited layout it loads
```

## Prerequisites

Python 3 must be installed before running any script. The current machine runs
Windows 11 IoT Enterprise LTSC, which ships without winget or the Store, so use
the installer from https://www.python.org/downloads/windows/ (tick "Add to PATH").
On editions with winget:
```bash
winget install Python.Python.3
```
Restart your terminal after installing so `python` is on the PATH.

## How to Use

### Full setup on a fresh machine
```bash
python windows/setup.py
```
Prompts y/n for each component, confirms selection, then runs chosen scripts in sequence.

### Installing a single component
```bash
python windows/vscode/install.py
python windows/sharex/install.py
python windows/ahk/install.py
python windows/theme/install.py
python windows/updates/install.py
```

## Notes per Script

### vscode/install.py
- Installs all VS Code extensions via `code --install-extension`
- Does not touch `settings.json` — that is handled by VS Code Settings Sync (personal GitHub account)

### sharex/install.py
- Installs ShareX via `winget install ShareX.ShareX`
- Imports the `.sxb` backup silently via `ShareX.exe -silent -importbackup`
- Searches common install paths for `ShareX.exe` automatically
- Config file path: `windows/sharex/ShareX-*.sxb`

### ahk/install.py
- Installs AutoHotkey v2 from the latest GitHub release (no winget needed); the installer
  isn't code-signed, so its sha256 is checked against the release digest before running
- Registers `windows/ahk/gmk104.ahk` as the `gmk104-ahk` startup entry in:
  `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
  and removes the old `keyboard-ahk` entry if present
- Starts the script right away; `#SingleInstance Force` replaces a running copy
- Uses the absolute resolved path at time of running — if the repo moves, re-run the script
- The startup entry needs no admin rights (HKCU scope); installing AHK may show a UAC prompt

### theme/install.py
- Windows take on the Plasma "Leaves" theme: reads colors from `linux/plasma/palette.json` and
  the wallpaper from `linux/plasma/wallpaper/leaves.png`, so `linux/plasma/DESIGN.md` stays the
  single source of truth; change colors there, then re-run
- Dark apps and system, transparency on (DESIGN.md's glass); the amber accent drives Windows'
  accent palette but stays off title bars, borders, taskbar and Start (one accented thing per view)
- Wallpaper (Fill) on the desktop and, via the WinRT LockScreen API, the lock and sign-in screen;
  Spotlight rotation and lock screen tips off. The file is copied to `%LOCALAPPDATA%\Leaves\`
- Taskbar: left-aligned (closest to the Leaves launcher at the top left), search box, Task View,
  Copilot and Widgets hidden. Widgets is guarded by Windows on 24H2 and reported as skipped
- Console windows (conhost; LTSC has no Windows Terminal): the Yakuake terminal colors from
  `yakuake/build.py` (bright = 25% toward white), amber cursor, JetBrains Mono 16px. Slot 0 is
  both background and ANSI black, so black is `bg` rather than `raised`; no glass, since conhost
  can't blur. JetBrains Mono v2.304 is installed per user, its sha256 pinned in the script
- Per-program overrides under `HKCU\Console` (PowerShell's blue) are cleared, and shortcuts
  carrying their own console block (PowerShell's Start menu and taskbar ones) have it stripped;
  originals are backed up once to `%LOCALAPPDATA%\Leaves\shortcut-backup\`
- Not portable without third-party tools: the 28px top bar with a centered clock, Noto Sans as
  the UI font, Leaves popups and motion, MingCute tray icons
- Per-user (HKCU), no admin needed; safe to re-run

### updates/install.py
- Runs `disable-updates.ps1 -Install` elevated (one UAC prompt) and prints what it changed
- Policy under `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate`: automatic updates
  off, no driver updates, Windows Update page in Settings blocked
- Services `wuauserv`, `UsoSvc`, `WaaSMedicSvc`, `dosvc` stopped and set to Disabled (`Start`=4
  in the registry, since Windows denies `Set-Service` on WaaSMedicSvc); Medic's failure actions
  cleared so it can't restart the others
- Disables the update scheduled tasks it can; most UpdateOrchestrator ones are protected even
  from admins and are reported as skipped (they do nothing with the services off)
- Registers the `disable-windows-updates` startup task (runs as SYSTEM), which re-applies all
  of this at every boot. It runs a copy in `C:\Program Files\scripts\` (admin-only writes),
  not the repo file, so re-run the install after editing `disable-updates.ps1`
- Each run logs to `C:\Program Files\scripts\disable-updates.log`
- Undo: delete the task and the policy key, then set `Start` back on the services
  (`wuauserv`=3, `UsoSvc`=2, `WaaSMedicSvc`=3, `dosvc`=2)

### ahk/gmk104.ahk
- Port of `linux/keyd/gmk104.conf` for the ZUOYA GMK104 with the Portuguese (Brazil) ABNT2 layout
- Hotkeys use scan codes (`SC035`, `SC027`, `SC02B`) to match physical keys like keyd does
- Keep it in sync with the keyd config when either changes; the keyd F19 sysrq/f10
  bindings are deliberately not ported (they only work around KWin and the Linux VT switch)
- Applies to every keyboard: AHK can't filter by device like keyd's `[ids]`
- Doesn't reach elevated (admin) windows unless AHK itself runs elevated

## Adding a New Script
1. Create `windows/<name>/install.py` following the existing pattern
2. Add an entry to the `SCRIPTS` list in `windows/setup.py`:
```python
{
    "key": "name",
    "label": "Display Name",
    "description": "One line description of what it does",
    "script": "name/install.py",
}
```
3. Place any config files or assets next to it in `windows/<name>/`

## What This Repo Does Not Handle
- Huion tablet config — managed separately, not work-related
- VS Code `settings.json` — synced automatically via VS Code Settings Sync
- VS Code theme or UI customizations — covered by Settings Sync
- Any software requiring license keys or account login during install
