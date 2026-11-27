#!/usr/bin/env python3
"""
Main Monitor Toggle Setup Script
Registers main-monitor.ahk (Win+Shift+M turns the Asus XG27ACS off and on) to run on startup.
Run with: python os/windows/monitor/install.py   (--uninstall to undo)
"""

import subprocess
import sys
import winreg
from pathlib import Path

# ── Config ────────────────────────────────────────────────────────────────────

HERE = Path(__file__).parent
AHK_SCRIPT = HERE / "main-monitor.ahk"
PS_SCRIPT = HERE / "main-monitor.ps1"
STARTUP_REG_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"
STARTUP_REG_NAME = "main-monitor-ahk"

# ── Helpers ───────────────────────────────────────────────────────────────────


def print_header(title):
    print(f"\n{'─' * 50}")
    print(f"  {title}")
    print(f"{'─' * 50}")


def find_ahk_exe():
    for path in (
        Path(r"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"),
        Path(r"C:\Program Files\AutoHotkey\v2\AutoHotkey.exe"),
    ):
        if path.exists():
            return path
    return None


def run_key(access):
    return winreg.OpenKey(winreg.HKEY_CURRENT_USER, STARTUP_REG_KEY, 0, access)


# ── Steps ─────────────────────────────────────────────────────────────────────


def check_monitor():
    print_header("Checking the Monitor")
    # status exits 1 when the monitor isn't connected: this setup is for the PC that has it
    result = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(PS_SCRIPT),
            "status",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    last = (result.stdout.strip().splitlines() or [""])[-1]
    if result.returncode != 0:
        print(f"  ✗ {last or result.stderr.strip()}")
        print("    This toggle is for the PC with the Asus XG27ACS; nothing installed.")
        sys.exit(1)
    print(f"  ✓ {last}")


def register_startup():
    print_header("Registering Startup Entry")
    ahk_exe = find_ahk_exe()
    if not ahk_exe:
        print("  ✗ AutoHotkey v2 isn't installed. Run python os/windows/ahk/install.py first.")
        sys.exit(1)
    reg_value = f'"{ahk_exe}" "{AHK_SCRIPT.resolve()}"'
    with run_key(winreg.KEY_SET_VALUE) as key:
        winreg.SetValueEx(key, STARTUP_REG_NAME, 0, winreg.REG_SZ, reg_value)
    print(f"  ✓ HKCU\\{STARTUP_REG_KEY}\\{STARTUP_REG_NAME}")
    print(f"    {reg_value}")
    # #SingleInstance Force replaces an already running copy
    subprocess.Popen([str(ahk_exe), str(AHK_SCRIPT.resolve())])
    print(f"  ✓ {AHK_SCRIPT.name} is running.")


def uninstall():
    print_header("Removing Main Monitor Toggle")
    try:
        with run_key(winreg.KEY_SET_VALUE) as key:
            winreg.DeleteValue(key, STARTUP_REG_NAME)
        print(f"  ✓ Removed startup entry {STARTUP_REG_NAME}")
    except FileNotFoundError:
        print("  ✓ No startup entry to remove")
    if find_ahk_exe():
        # Stop the running copy, found by its script path on the command line
        subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-Command",
                (
                    "Get-CimInstance Win32_Process -Filter \"Name like 'AutoHotkey%'\" | "
                    f"Where-Object CommandLine -like '*{AHK_SCRIPT.name}*' | "
                    "ForEach-Object { Stop-Process -Id $_.ProcessId }"
                ),
            ],
            check=False,
        )
        print(f"  ✓ Stopped {AHK_SCRIPT.name}")
    print()


def done():
    print_header("Main Monitor Toggle Installed")
    print("  Win+Shift+M turns the Asus off and back on; it starts with Windows.")
    print(
        "  From a shell: powershell -File os/windows/monitor/main-monitor.ps1 [toggle|off|on|status]"
    )
    print()


# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    if "--uninstall" in sys.argv[1:]:
        uninstall()
        sys.exit(0)
    print("\n  Main Monitor Toggle Setup")
    check_monitor()
    register_startup()
    done()
