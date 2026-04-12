# scripts

Personal machine setup and automation scripts for Windows. This repo is used to bootstrap a new machine or reinstall individual tools granularly.

## Repo Structure

```
scripts/
  setup.py              ← Master orchestrator, runs selected scripts interactively
  setup-vscode.py       ← Installs VS Code extensions
  setup-sharex.py       ← Installs ShareX and imports backup config
  setup-ahk.py          ← Installs AutoHotkey v2 and registers keyboard.ahk on startup
  sharex/
    ShareX-*.sxb        ← ShareX backup config (exported from Application Settings → Export)
  ahk/
    keyboard.ahk        ← AHK v2 script, registered to run on Windows startup
```

## Prerequisites

Python 3 must be installed before running any script:
```bash
winget install Python.Python.3
```
Restart your terminal after installing so `python` is on the PATH.

## How to Use

### Full setup on a fresh machine
```bash
python setup.py
```
Prompts y/n for each component, confirms selection, then runs chosen scripts in sequence.

### Installing a single component
```bash
python setup-vscode.py
python setup-sharex.py
python setup-ahk.py
```

## Notes per Script

### setup-vscode.py
- Installs all VS Code extensions via `code --install-extension`
- Does not touch `settings.json` — that is handled by VS Code Settings Sync (personal GitHub account)

### setup-sharex.py
- Installs ShareX via `winget install ShareX.ShareX`
- Imports the `.sxb` backup silently via `ShareX.exe -silent -importbackup`
- Searches common install paths for `ShareX.exe` automatically
- Config file path: `scripts/sharex/ShareX-*.sxb`

### setup-ahk.py
- Installs AutoHotkey v2 via `winget install AutoHotkey.AutoHotkey`
- Registers `scripts/ahk/keyboard.ahk` as a startup entry in:
  `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
- Uses the absolute resolved path at time of running — if the repo moves, re-run the script
- Does not require admin rights (HKCU scope)

## Adding a New Script
1. Create `setup-<name>.py` at the repo root following the existing pattern
2. Add an entry to the `SCRIPTS` list in `setup.py`:
```python
{
    "key": "name",
    "label": "Display Name",
    "description": "One line description of what it does",
    "script": "setup-name.py",
}
```
3. Place any config files or assets under `<name>/` at the repo root

## What This Repo Does Not Handle
- Huion tablet config — managed separately, not work-related
- VS Code `settings.json` — synced automatically via VS Code Settings Sync
- VS Code theme or UI customizations — covered by Settings Sync
- Any software requiring license keys or account login during install
