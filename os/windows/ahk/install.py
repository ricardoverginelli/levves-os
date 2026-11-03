#!/usr/bin/env python3
"""
AutoHotkey v2 Setup Script
Installs AHK v2 from its GitHub release and registers gmk104.ahk to run on startup.
Run with: python os/windows/ahk/install.py
"""

import hashlib
import json
import subprocess
import sys
import tempfile
import urllib.request
import winreg
from pathlib import Path

# ── Config ────────────────────────────────────────────────────────────────────

AHK_SCRIPT = Path(__file__).parent / "gmk104.ahk"
# No winget on LTSC, so install from the GitHub release instead
AHK_RELEASE_API = "https://api.github.com/repos/AutoHotkey/AutoHotkey/releases/latest"
STARTUP_REG_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"
STARTUP_REG_NAME = "gmk104-ahk"
# Entry written by the old keyboard.ahk setup, removed on install
OLD_STARTUP_REG_NAME = "keyboard-ahk"

# ── Helpers ───────────────────────────────────────────────────────────────────

def print_header(title):
    print(f"\n{'─' * 50}")
    print(f"  {title}")
    print(f"{'─' * 50}")

def find_ahk_exe():
    """Try to locate AutoHotkey v2 executable after install."""
    candidates = [
        Path(r"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"),
        Path(r"C:\Program Files\AutoHotkey\v2\AutoHotkey.exe"),
    ]
    for path in candidates:
        if path.exists():
            return path
    return None

def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "scripts-setup-ahk"})
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)

# ── Steps ─────────────────────────────────────────────────────────────────────

def check_script():
    print_header("Checking AHK Script")
    if not AHK_SCRIPT.exists():
        print(f"  ✗ Script not found at: {AHK_SCRIPT}")
        print(f"    Make sure gmk104.ahk is next to this script in os/windows/ahk/.")
        sys.exit(1)
    print(f"  ✓ Script found: {AHK_SCRIPT.name}")

def install_ahk():
    print_header("Installing AutoHotkey v2")

    if find_ahk_exe():
        print("  ✓ AutoHotkey v2 is already installed, skipping.")
        return

    try:
        release = fetch_json(AHK_RELEASE_API)
    except Exception as e:
        print(f"  ✗ Could not reach GitHub: {e}")
        sys.exit(1)

    asset = next((a for a in release["assets"] if a["name"].endswith("_setup.exe")), None)
    if not asset:
        print(f"  ✗ No setup.exe in AutoHotkey release {release['tag_name']}.")
        sys.exit(1)

    # The installer isn't code-signed, so check it against GitHub's digest
    expected = (asset.get("digest") or "").removeprefix("sha256:")
    if not expected:
        print(f"  ✗ GitHub gave no sha256 for {asset['name']}, refusing to run it.")
        sys.exit(1)

    print(f"  Downloading {asset['name']}...")
    installer = Path(tempfile.mkdtemp()) / asset["name"]
    urllib.request.urlretrieve(asset["browser_download_url"], installer)

    actual = hashlib.sha256(installer.read_bytes()).hexdigest()
    if actual != expected:
        print(f"  ✗ sha256 mismatch for {asset['name']}:")
        print(f"      expected {expected}")
        print(f"      got      {actual}")
        sys.exit(1)
    print("  ✓ sha256 matches the GitHub release.")

    print("  Installing (accept the UAC prompt if one appears)...")
    result = subprocess.run([str(installer), "/silent"])
    if result.returncode != 0 or not find_ahk_exe():
        print(f"  ✗ AutoHotkey install failed (exit code {result.returncode}).")
        print("    Try running this script as Administrator.")
        sys.exit(1)

    print(f"  ✓ AutoHotkey {release['tag_name']} installed.")

def register_startup():
    print_header("Registering Startup Entry")

    ahk_exe = find_ahk_exe()
    if not ahk_exe:
        print("  ✗ Could not locate AutoHotkey executable.")
        print("    Expected: C:\\Program Files\\AutoHotkey\\v2\\AutoHotkey64.exe")
        sys.exit(1)

    # Registry value: "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" "C:\...\gmk104.ahk"
    reg_value = f'"{ahk_exe}" "{AHK_SCRIPT.resolve()}"'

    try:
        key = winreg.OpenKey(
            winreg.HKEY_CURRENT_USER,
            STARTUP_REG_KEY,
            0,
            winreg.KEY_SET_VALUE
        )
        winreg.SetValueEx(key, STARTUP_REG_NAME, 0, winreg.REG_SZ, reg_value)
        try:
            winreg.DeleteValue(key, OLD_STARTUP_REG_NAME)
            print(f"  ✓ Removed old startup entry: {OLD_STARTUP_REG_NAME}")
        except FileNotFoundError:
            pass
        winreg.CloseKey(key)
        print(f"  ✓ Startup entry registered:")
        print(f"    Key:   HKCU\\{STARTUP_REG_KEY}")
        print(f"    Name:  {STARTUP_REG_NAME}")
        print(f"    Value: {reg_value}")
    except PermissionError:
        print("  ✗ Permission denied writing to registry.")
        print("    Try running this script as Administrator.")
        sys.exit(1)
    except Exception as e:
        print(f"  ✗ Registry write failed: {e}")
        sys.exit(1)

def start_script():
    print_header("Starting AHK Script")
    # #SingleInstance Force in the script replaces an already running copy
    subprocess.Popen([str(find_ahk_exe()), str(AHK_SCRIPT.resolve())])
    print(f"  ✓ {AHK_SCRIPT.name} is running.")

def done():
    print_header("AHK Setup Complete")
    print(f"  {AHK_SCRIPT.name} is running and will start automatically on login.")
    print()

# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("\n  AutoHotkey v2 Setup")
    check_script()
    install_ahk()
    register_startup()
    start_script()
    done()
