#!/usr/bin/env python3
"""
Windows Update Setup Script
Turns Windows Update off and registers a startup task that keeps it off.
Run with: python os/windows/updates/install.py
"""

import os
import subprocess
import sys
from pathlib import Path

# ── Config ────────────────────────────────────────────────────────────────────

PS_SCRIPT = Path(__file__).parent / "disable-updates.ps1"
LOG_FILE = Path(os.environ["ProgramFiles"]) / "scripts" / "disable-updates.log"

# ── Helpers ───────────────────────────────────────────────────────────────────

def print_header(title):
    print(f"\n{'─' * 50}")
    print(f"  {title}")
    print(f"{'─' * 50}")

# ── Steps ─────────────────────────────────────────────────────────────────────

def check_script():
    print_header("Checking PowerShell Script")
    if not PS_SCRIPT.exists():
        print(f"  ✗ Script not found at: {PS_SCRIPT}")
        sys.exit(1)
    print(f"  ✓ Script found: {PS_SCRIPT.name}")

def run_elevated():
    print_header("Disabling Windows Update")
    print("  Running as Administrator (accept the UAC prompt)...")
    # Start-Process -Verb RunAs shows UAC; -Wait/-PassThru hand back the exit code
    launcher = (
        "$p = Start-Process powershell -Verb RunAs -Wait -PassThru -ArgumentList "
        f"'-NoProfile','-ExecutionPolicy','Bypass','-File','\"{PS_SCRIPT.resolve()}\"','-Install'; "
        "exit $p.ExitCode"
    )
    result = subprocess.run(["powershell", "-NoProfile", "-Command", launcher])
    if result.returncode != 0:
        print(f"  ✗ Elevated run failed (exit code {result.returncode}). Was UAC declined?")
        sys.exit(1)

    if LOG_FILE.exists():
        for line in LOG_FILE.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith(("Disabled", "Registered", "FAILED", "Skipped")):
                print(f"  {'✗' if line.startswith('FAILED') else '✓'} {line}")
    print(f"  Full log: {LOG_FILE}")

def done():
    print_header("Windows Update Setup Complete")
    print("  Updates are off and the 'disable-windows-updates' task re-applies this at every boot.")
    print("  Re-run this script after editing disable-updates.ps1 to refresh the installed copy.")
    print()

# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("\n  Windows Update Setup")
    check_script()
    run_elevated()
    done()
