#!/usr/bin/env python3
"""
ShareX Setup Script
Installs ShareX via winget and imports backup config.
Run with: python os/windows/sharex/install.py
"""

import subprocess
import sys
import time
from pathlib import Path

# ── Config ────────────────────────────────────────────────────────────────────

SHAREX_CONFIG = Path(__file__).parent / "ShareX-19.0.2.sxb"
SHAREX_WINGET_ID = "ShareX.ShareX"

# ── Helpers ───────────────────────────────────────────────────────────────────


def print_header(title):
    print(f"\n{'─' * 50}")
    print(f"  {title}")
    print(f"{'─' * 50}")


def run(cmd, capture=True):
    result = subprocess.run(cmd, shell=True, capture_output=capture, text=True, check=False)
    return result.returncode == 0, result.stdout.strip(), result.stderr.strip()


def find_sharex_exe():
    """Try to locate ShareX.exe after install."""
    candidates = [
        Path(r"C:\Program Files\ShareX\ShareX.exe"),
        Path(r"C:\Program Files (x86)\ShareX\ShareX.exe"),
        Path.home() / "AppData" / "Local" / "Programs" / "ShareX" / "ShareX.exe",
    ]
    for path in candidates:
        if path.exists():
            return path
    return None


# ── Steps ─────────────────────────────────────────────────────────────────────


def check_config():
    print_header("Checking Config File")
    if not SHAREX_CONFIG.exists():
        print(f"  ✗ Config file not found at: {SHAREX_CONFIG}")
        print("    Make sure ShareX-19.0.2.sxb is next to this script in os/windows/sharex/.")
        sys.exit(1)
    print(f"  ✓ Config file found: {SHAREX_CONFIG.name}")


def install_sharex():
    print_header("Installing ShareX")

    # Check if already installed
    ok, out, _ = run(f"winget list --id {SHAREX_WINGET_ID}")
    if ok and "ShareX" in out:
        print("  ✓ ShareX is already installed, skipping.")
        return

    print("  Installing via winget...")
    ok, _, err = run(
        f"winget install --id {SHAREX_WINGET_ID} --silent --accept-package-agreements --accept-source-agreements",
        capture=False,
    )
    if not ok:
        print(f"  ✗ winget install failed: {err}")
        print("    Try running this script as Administrator.")
        sys.exit(1)

    print("  ✓ ShareX installed.")
    print("  Waiting for install to settle...")
    time.sleep(3)


def import_config():
    print_header("Importing ShareX Config")

    sharex_exe = find_sharex_exe()
    if not sharex_exe:
        print("  ✗ Could not locate ShareX.exe.")
        print("    Common locations checked:")
        print("      C:\\Program Files\\ShareX\\ShareX.exe")
        print("      C:\\Program Files (x86)\\ShareX\\ShareX.exe")
        print("    Run this manually after locating ShareX:")
        print(f'      ShareX.exe -silent -importbackup "{SHAREX_CONFIG}"')
        sys.exit(1)

    print(f"  Found ShareX at: {sharex_exe}")
    print(f"  Importing: {SHAREX_CONFIG.name}")

    ok, _, err = run(f'"{sharex_exe}" -silent -importbackup "{SHAREX_CONFIG}"')
    if not ok:
        print(f"  ✗ Import failed: {err}")
        print(f'    Try running manually: "{sharex_exe}" -silent -importbackup "{SHAREX_CONFIG}"')
        sys.exit(1)

    print("  ✓ Config imported successfully.")


def done():
    print_header("ShareX Setup Complete")
    print("  Launch ShareX to verify your settings and hotkeys are applied.")
    print()


# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("\n  ShareX Setup")
    check_config()
    install_sharex()
    import_config()
    done()
