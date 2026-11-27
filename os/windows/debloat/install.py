#!/usr/bin/env python3
"""
Debloat Setup Script
Turns off telemetry, ads, suggestions and background noise (needs admin).
Run with: python os/windows/debloat/install.py
          python os/windows/debloat/install.py --survey            (read-only listing)
          python os/windows/debloat/install.py --remove NAME ...   (also remove these appx packages)
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path

# ── Config ──────────────────────────────────────────────────────────────────

PS_SCRIPT = Path(__file__).parent / "debloat.ps1"
LOG_DIR = Path(os.environ["ProgramFiles"]) / "scripts"
SUMMARY_PREFIXES = (
    "Set",
    "Disabled",
    "Removed",
    "Skipped",
    "FAILED",
    "Created",
    "Registered",
    "Added",
    "Updated",
    "Verified",
)

# ── Helpers ─────────────────────────────────────────────────────────────────


def print_header(title):
    print(f"\n{'─' * 50}")
    print(f"  {title}")
    print(f"{'─' * 50}")


# ── Steps ───────────────────────────────────────────────────────────────────


def check_script():
    print_header("Checking PowerShell Script")
    if not PS_SCRIPT.exists():
        print(f"  ✗ Script not found at: {PS_SCRIPT}")
        sys.exit(1)
    print(f"  ✓ Script found: {PS_SCRIPT.name}")


def run_elevated(survey, remove):
    print_header("Surveying the System" if survey else "Debloating Windows")
    print("  Running as Administrator (accept the UAC prompt)...")
    ps_args = [f"'\"{PS_SCRIPT.resolve()}\"'"]
    if survey:
        ps_args.append("'-Survey'")
    if remove:
        ps_args += ["'-RemoveApps'", "'" + ",".join(remove) + "'"]
    # Start-Process -Verb RunAs shows UAC; -Wait/-PassThru hand back the exit code
    launcher = (
        "$p = Start-Process powershell -Verb RunAs -Wait -PassThru -ArgumentList "
        "'-NoProfile','-ExecutionPolicy','Bypass','-File'," + ",".join(ps_args) + "; "
        "exit $p.ExitCode"
    )
    result = subprocess.run(["powershell", "-NoProfile", "-Command", launcher], check=False)
    if result.returncode != 0:
        print(f"  ✗ Elevated run failed (exit code {result.returncode}). Was UAC declined?")
        sys.exit(1)

    log = LOG_DIR / ("debloat-survey.log" if survey else "debloat.log")
    if log.exists() and not survey:
        for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith(SUMMARY_PREFIXES):
                print(f"  {'✗' if line.startswith('FAILED') else '✓'} {line}")
    print(f"  Full log: {log}")


def done(survey):
    if survey:
        print_header("Survey Complete")
        print("  Nothing was changed. Pass app names from the log to --remove to remove them.")
    else:
        print_header("Debloat Complete")
        print("  Reboot once, then check sound, a plugin installer window and a game launcher.")
    print()


# ── Main ────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Turn off Windows telemetry, ads and background noise"
    )
    parser.add_argument(
        "--survey", action="store_true", help="only list apps, features, services and tasks"
    )
    parser.add_argument(
        "--remove", nargs="+", default=[], metavar="NAME", help="appx package names to remove"
    )
    args = parser.parse_args()

    print("\n  Debloat Setup")
    check_script()
    run_elevated(args.survey, args.remove)
    done(args.survey)
