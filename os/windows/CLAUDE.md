# scripts

Personal machine setup and automation scripts. Windows setup lives in `os/windows/`, Linux setup in
`os/linux/`; each has one folder per component. This file covers `os/windows/`. It's used to bootstrap a
new machine or reinstall individual tools granularly.

## Repo Structure

```
os/windows/
  setup.py              ← Master orchestrator, runs selected components interactively
  vscode/install.py     ← Installs VS Code extensions
  sharex/
    install.py          ← Installs ShareX and imports backup config
    ShareX-*.sxb        ← ShareX backup config (exported from Application Settings → Export)
  ahk/
    install.py          ← Installs AutoHotkey v2 and registers gmk104.ahk on startup
    gmk104.ahk          ← AHK v2 keyboard remap, Windows port of os/linux/keyd/gmk104.conf
  dropdown/             ← Yakuake on Windows: Windows Terminal docked left, slid in on Win+/
    install.py          ← Installs portable Windows Terminal, writes its settings, registers dropdown.ahk
    dropdown.ahk        ← The hotkeys, docking, slide and fullscreen avoidance
  monitor/              ← Win+Shift+M turns the main monitor off/on, port of os/linux/monitor (this PC only)
    install.py          ← Registers main-monitor.ahk on startup
    main-monitor.ps1    ← toggle|off|on|status; main-monitor.ahk binds the hotkey
  drive-mirror/         ← drive-push: uploads edits on the Drive Mirror HDD to Google Drive (this PC only)
    install.py          ← Installs rclone, puts drive-push on the PATH, signs in gdrive-rw
    drive-push.ps1      ← rclone copy <disk> gdrive-rw: --update, changed files only except daily
  theme/install.py      ← Applies the Leaves look (from os/linux/plasma/) to Windows
  updates/
    install.py          ← Turns Windows Update off and keeps it off at every boot (admin)
    disable-updates.ps1 ← The policy/service/task changes; also what the startup task runs
  debloat/
    install.py          ← Turns off telemetry, ads, suggestions and background noise (admin)
    debloat.ps1         ← The changes, a restore point first, a read-only -Survey mode
  gmk104-image-tool/    ← The edited layout for the GMK104's screen; the vendor tool is a release asset (README.md)
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
python os/windows/setup.py
```
Prompts y/n for each component, confirms selection, then runs chosen scripts in sequence.

### Installing a single component
```bash
python os/windows/vscode/install.py
python os/windows/sharex/install.py
python os/windows/ahk/install.py
python os/windows/dropdown/install.py
python os/windows/monitor/install.py
python os/windows/drive-mirror/install.py
python os/windows/theme/install.py
python os/windows/updates/install.py
python os/windows/debloat/install.py
```

## Notes per Script

### vscode/install.py
- Installs all VS Code extensions via `code --install-extension`
- Does not touch `settings.json` — that is handled by VS Code Settings Sync (personal GitHub account)

### sharex/install.py
- Installs ShareX via `winget install ShareX.ShareX`
- Imports the `.sxb` backup silently via `ShareX.exe -silent -importbackup`
- Searches common install paths for `ShareX.exe` automatically
- Config file path: `os/windows/sharex/ShareX-*.sxb`

### ahk/install.py
- Installs AutoHotkey v2 from the latest GitHub release (no winget needed); the installer
  isn't code-signed, so its sha256 is checked against the release digest before running
- Registers `os/windows/ahk/gmk104.ahk` as the `gmk104-ahk` startup entry in:
  `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
  and removes the old `keyboard-ahk` entry if present
- Starts the script right away; `#SingleInstance Force` replaces a running copy
- Uses the absolute resolved path at time of running — if the repo moves, re-run the script
- The startup entry needs no admin rights (HKCU scope); installing AHK may show a UAC prompt

### dropdown/
- Yakuake on Windows (the Linux side is `os/linux/kwin/yakuake-*` and `plasma/yakuake/`).
  `Win+/` opens and retracts it, or focuses it when it's open behind another window; `Win+N`
  adds a PowerShell tab, `Win+Shift+N` a Claude Code tab. `Win+/` is the key right of `.`
  (`SC035`, the GMK104's `/` through `gmk104.ahk`) or ABNT2's own `/` (`SC073`). These replace
  Windows' Win+N (notifications) and Win+Shift+N
- `install.py` downloads the portable Windows Terminal zip from the latest GitHub release
  (LTSC has no Store), checks its sha256 against the release digest, and unpacks it to
  `%LOCALAPPDATA%\levves\terminal\` with a `.portable` file, so its settings live in
  `settings\settings.json` there. Skips the download when that version is installed; refuses
  to update while the terminal runs (its files are locked)
- Settings are rewritten on every run (edit `install.py`, not the file): one window for every
  launch (`windowingBehavior: useExisting`), always on top, the Yakuake scheme from
  `design/dist` (bright 25% toward white), title-bar tokens for the tab row, JetBrains Mono 12pt
  (installed by `theme/`), PowerShell (Windows PowerShell 5.1) as the default profile and
  Claude Code when `claude` is on the PATH; cmd and the generated WSL/Azure/VS profiles hidden.
  `Shift+Left/Right` move between split panes; tabs stay on Ctrl+Tab / Ctrl+Shift+Tab, since
  Windows Terminal can't fall through from the last pane to the next tab like `yakuake-panes`
- `dropdown.ahk` docks it on the left of the focused window's monitor (30% of the work area,
  full height; Windows' invisible resize borders measured with DWM so the visible edges land
  on the work area), slides it in and out with `SetWindowPos` on the out-quint curve, one step
  per DWM frame, then hides it (no taskbar button while open either, `ITaskbarList::DeleteTab`).
  Focus goes back to the previous window on retract. A fullscreen window (a game) on that
  monitor sends it to the next monitor. The durations come from `design/dist`
  (`duration.panel-open/close`) as arguments in the startup entry, not copied into the script
- Known gaps: a fresh launch shows Windows Terminal's first frame for ~150ms before it's
  docked; the slide isn't clipped, so with a monitor to the left it passes over that one; the
  tab row keeps Windows' minimize/maximize/close buttons; new tabs open PowerShell or Claude
  Code, not `agents/launcher` (it needs `wl-copy` and `os.execvp` ported first)
- Startup entry `dropdown-ahk` (HKCU, no admin); needs AHK (`ahk/install.py`). `--uninstall`
  removes it, stops the script and deletes the terminal folder (when it isn't running)

### monitor/
- Port of `os/linux/monitor`: `Win+Shift+M` turns the Asus XG27ACS off and back on, to hand it
  to another device on another input. Replaces Windows' own Win+Shift+M (restore minimized)
- `main-monitor.ps1 [toggle|off|on|status]`, through `ChangeDisplaySettingsEx`: **off** saves
  the Asus's mode and every screen's position to `%LOCALAPPDATA%\levves\main-monitor.json`,
  makes the next screen primary (Windows keeps the primary at 0,0, so the layout shifts) and
  detaches the Asus (Display settings' "Disconnect this display"); won't turn off the only
  screen. **on** re-attaches it with that mode, makes it primary and puts the others back
- Found by hardware ID (`-MonitorId`, default `AUS27FE`), not by being primary as on Linux,
  since primary moves to the other screen while it's off. Only an attached output's first
  monitor counts: once detached, Windows lists the Asus under every output, the LG's included
- `install.py` refuses where the Asus isn't connected, needs AHK (`ahk/install.py`), and
  registers `main-monitor.ahk` as the `main-monitor-ahk` startup entry (HKCU, no admin);
  `--uninstall` removes it and stops the running copy. Machine-only: `.only-on`

### drive-mirror/
- The Windows half of `os/linux/drive-mirror`. That one-way `rclone sync` would move files
  edited on the disk but missing from the cloud to `_rclone-removed/`, so it refuses to sync
  while the disk has changes newer than the last successful push (see the Linux README)
- `drive-push [--full] [--dry-run] [rclone flags]`: `rclone copy <disk> gdrive-rw: --update`.
  Copy, not sync, so it never deletes in the cloud, and `--update` skips files newer there
- Quick pass (most runs): scans the disk for files whose write or creation time is after the
  `.drive-push-ok` stamp (or Fedora's `.drive-mirror-ok`, whichever is newer, minus 10 min) and
  copies just those with `--files-from-raw --no-traverse`. The scan takes ~1 s warm (~100 s
  cold); the old full pass took ~15 minutes listing ~540k objects, and a shutdown in that
  window lost Ableton saves to `_rclone-removed/` on 2026-10-31 and 2026-11-11
- Full pass: first run, `--full`, or when the last one is over 20 hours old (`last-full` in the
  log folder). Catches renames and moves, which keep a file's times
- A successful run sets the hidden `<disk>\.drive-push-ok` to its start time; a dry run doesn't
- Toast notifications when rclone fails, and at the next run when the last one was cut off
  (the `running` file in the log folder was left behind)
- Finds the disk by label `Drive Mirror` and NTFS serial `C236DF7C`, not by letter (`D:`
  today); refuses to run without it
- Same excludes and `--drive-export-formats docx,xlsx,pptx,svg` as Linux, so the mirrored
  `.docx/.xlsx/.pptx` match their Google Docs (checked 2026-11-08: none were queued). No
  `--local-encoding`: rclone on Windows already uses the encoding Linux sets
- `install.py` installs rclone from the GitHub release zip (sha256 checked against the
  release digest) to `%LOCALAPPDATA%\Programs\rclone\`, writes the `drive-push.cmd` shim
  to `%LOCALAPPDATA%\levves\bin\`, adds both to the user PATH, and creates the `gdrive-rw`
  remote (`scope=drive`, browser sign-in; skipped if it exists). The Linux `gdrive` remote
  stays read-only. Re-run after the repo moves (the shim holds its absolute path)
- Runs on its own through the `drive-push` scheduled task (current user, no admin): 2 minutes
  after logon and every 30 minutes, through `conhost --headless` so no window shows. A run that
  overlaps another is skipped (the task's IgnoreNew, plus a mutex in the script for manual runs)
- Logs to `%LOCALAPPDATA%\drive-mirror\push_*.log`, kept 90 days
- Uses rclone's shared client ID, which is being retired during 2026 (see the Linux README);
  `rclone config update gdrive-rw client_id=... client_secret=...` once there's an own one
- `--uninstall` removes the task, rclone, the shim and the PATH entries; the remote stays in
  `%APPDATA%\rclone\rclone.conf`. Machine-only: `.only-on`

### theme/install.py
- Windows take on the Plasma "Leaves" theme: reads colors from `design/dist/levves_tokens.py` and
  the wallpaper from `os/linux/plasma/wallpaper/urban-flora.png`, so the design tokens (`design/tokens/`)
  stay the single source of truth; change a token, rebuild, then re-run
- Dark apps and system, transparency off (Levves is opaque); the amber accent drives Windows'
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

### debloat/install.py
- Runs `debloat.ps1` elevated (one UAC prompt) and prints the log summary. LTSC is already
  lean, so this is privacy, telemetry, ads and background noise, not ripping out components
- Creates a restore point first ("Before debloat (levves repo)"; Windows allows one per 24h)
- `--survey` only lists all-users/provisioned appx packages, capabilities, enabled features,
  running services, startup entries and non-Microsoft tasks, to `debloat-survey.log`. Every
  apply run logs the same listing first. Apps are removed only when named with
  `--remove NAME ...` (installed and provisioned); on 2026-10-29 there was nothing worth removing
- Telemetry: `DiagTrack` and `dmwappushservice` disabled; Application Experience, CEIP,
  DiskDiagnostic, Feedback\Siuf and WER QueueReporting tasks disabled; DataCollection, WER,
  AppCompat, activity history, tailored experiences and SQM/CEIP policies; per-user feedback
  prompts, inking/typing personalization and the website language list off
- AI and search: Recall/AI data analysis (HKLM and HKCU) and Copilot off by policy; Cortana,
  web and cloud results off in search. The Windows Search service stays
- Ads: ContentDeliveryManager suggestions and silent app installs off, Start recommendations,
  account notifications and Settings suggestions off. Lock screen values stay with `theme/`
- Edge stays installed and updating (WebView2 shares the updater; plugin installers, license
  managers and Claude desktop render with it); policies turn off startup boost, background
  mode, first-run, recommendations and diagnostic data, and its auto-launch Run entry is removed
- Game DVR off; High performance power plan, with USB selective suspend (Audient iD4 dropouts)
  and PCIe link state power management off
- Registers `update-defender-signatures` (SYSTEM, weekly, Sundays 12:00) running
  `MpCmdRun.exe -SignatureUpdate -MMPC`, since signatures normally come through Windows
  Update, which `updates/` turns off; runs it once right away
- Re-reads every registry value it set and reports any that didn't stick
- Never touches Defender settings, SmartScreen, the firewall, UAC, Secure Boot/TPM (Vanguard),
  audio services, Print Spooler, Windows Search, BITS, `bcdedit`/EFI or the other disks
- No startup task: with Windows Update off, nothing turns these back on. Safe to re-run
- Logs to `C:\Program Files\scripts\debloat.log`
- Undo: roll back to the restore point, or per group: delete the policy values it set (under
  `HKLM\SOFTWARE\Policies\Microsoft\Windows\{DataCollection,Windows Error Reporting,AppCompat,
  System,CloudContent,WindowsAI,Windows Search,GameDVR}`, `...\Microsoft\SQMClient`,
  `...\Microsoft\Edge` and `HKCU\Software\Policies\Microsoft\Windows`); set `DiagTrack` `Start`=2
  and `dmwappushservice` `Start`=3; re-enable the tasks with `Enable-ScheduledTask`; set the
  HKCU ContentDeliveryManager/Explorer values back to 1; `powercfg /setactive SCHEME_BALANCED`;
  `Unregister-ScheduledTask update-defender-signatures`

### ahk/gmk104.ahk
- Port of `os/linux/keyd/gmk104.conf` for the ZUOYA GMK104 with the Portuguese (Brazil) ABNT2 layout
- Hotkeys use scan codes (`SC035`, `SC027`, `SC02B`) to match physical keys like keyd does
- Keep it in sync with the keyd config when either changes; the keyd F19 sysrq/f10
  bindings are deliberately not ported (they only work around KWin and the Linux VT switch)
- Numpad 5 (`SC04C`, NumLock on or off) toggles the default recording device's mute through the
  Core Audio COM API, since Windows has no mic-mute key like keyd's `micmute`; a 1s tooltip
  stands in for Plasma's OSD
- Applies to every keyboard: AHK can't filter by device like keyd's `[ids]`
- Doesn't reach elevated (admin) windows unless AHK itself runs elevated

## Adding a New Script
1. Create `os/windows/<name>/install.py` following the existing pattern
2. Add an entry to the `SCRIPTS` list in `os/windows/setup.py`:
```python
{
    "key": "name",
    "label": "Display Name",
    "description": "One line description of what it does",
    "script": "name/install.py",
}
```
3. Place any config files or assets next to it in `os/windows/<name>/`

## What This Repo Does Not Handle
- Huion tablet config — managed separately, not work-related
- VS Code `settings.json` — synced automatically via VS Code Settings Sync
- VS Code theme or UI customizations — covered by Settings Sync
- Any software requiring license keys or account login during install
