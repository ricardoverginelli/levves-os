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

### theme/install.py
- Windows take on the Plasma "Leaves" theme: reads colors from `design/dist/palette.json` and
  the wallpaper from `os/linux/plasma/wallpaper/leaves.png`, so the design tokens (`design/tokens/`)
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
