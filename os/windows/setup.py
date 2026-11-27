#!/usr/bin/env python3
"""
Master Setup Orchestrator
Runs selected setup scripts for a fresh machine configuration.
Run with: python os/windows/setup.py
"""

import subprocess
import sys
from pathlib import Path

# ── Config ────────────────────────────────────────────────────────────────────

SCRIPTS = [
    {
        "key": "vscode",
        "label": "VS Code",
        "description": "Install extensions and copy Git config files",
        "script": "vscode/install.py",
    },
    {
        "key": "sharex",
        "label": "ShareX",
        "description": "Install ShareX and import backup config",
        "script": "sharex/install.py",
    },
    {
        "key": "ahk",
        "label": "AutoHotkey v2",
        "description": "Install AHK v2 and register gmk104.ahk (keyboard remap) on startup",
        "script": "ahk/install.py",
    },
    {
        "key": "dropdown",
        "label": "Drop-down terminal",
        "description": "Yakuake on Windows: portable Windows Terminal on Win+/ (needs AHK)",
        "script": "dropdown/install.py",
    },
    {
        "key": "monitor",
        "label": "Main monitor toggle",
        "description": "Win+Shift+M turns the Asus off and on (this PC only; needs AHK)",
        "script": "monitor/install.py",
    },
    {
        "key": "drive-mirror",
        "label": "Drive push",
        "description": "rclone and drive-push: upload edits on the Drive Mirror HDD (this PC only)",
        "script": "drive-mirror/install.py",
    },
    {
        "key": "theme",
        "label": "Leaves theme",
        "description": "Dark mode, amber accent, leaves wallpaper and a minimal taskbar",
        "script": "theme/install.py",
    },
    {
        "key": "updates",
        "label": "Windows Update off",
        "description": "Disable Windows Update and keep it off with a startup task (needs admin)",
        "script": "updates/install.py",
    },
    {
        "key": "debloat",
        "label": "Debloat",
        "description": "Telemetry, ads, suggestions and background noise off (needs admin)",
        "script": "debloat/install.py",
    },
]

# ── Helpers ───────────────────────────────────────────────────────────────────


def print_header(title):
    print(f"\n{'─' * 50}")
    print(f"  {title}")
    print(f"{'─' * 50}")


def print_divider():
    print(f"\n{'═' * 50}")


def ask_yes_no(question):
    while True:
        answer = input(f"  {question} [y/n]: ").strip().lower()
        if answer in ("y", "yes"):
            return True
        if answer in ("n", "no"):
            return False
        print("  Please enter y or n.")


# ── Steps ─────────────────────────────────────────────────────────────────────


def select_scripts():
    print_header("Select Setup Scripts to Run")
    selected = []
    for s in SCRIPTS:
        run_it = ask_yes_no(f"{s['label']} — {s['description']}. Include?")
        if run_it:
            selected.append(s)

    return selected


def confirm_selection(selected):
    if not selected:
        print("\n  Nothing selected. Exiting.")
        sys.exit(0)

    print_header("Ready to Run")
    print("  The following scripts will run in order:\n")
    for i, s in enumerate(selected, 1):
        print(f"  {i}. {s['label']} ({s['script']})")

    print()
    proceed = ask_yes_no("Proceed?")
    if not proceed:
        print("\n  Cancelled. Exiting.")
        sys.exit(0)


def run_scripts(selected):
    script_dir = Path(__file__).parent
    results = []

    for s in selected:
        print_divider()
        print(f"\n  Running: {s['label']}\n")

        script_path = script_dir / s["script"]
        if not script_path.exists():
            print(f"  ✗ Script not found: {script_path}")
            results.append((s["label"], False, "Script file not found"))
            continue

        result = subprocess.run(
            [sys.executable, str(script_path)], cwd=str(script_dir), check=False
        )

        success = result.returncode == 0
        results.append(
            (s["label"], success, "OK" if success else f"Exited with code {result.returncode}")
        )

    return results


def print_summary(results):
    print_divider()
    print_header("Setup Summary")
    all_ok = True
    for label, success, message in results:
        status = "✓" if success else "✗"
        print(f"  {status} {label} — {message}")
        if not success:
            all_ok = False

    print()
    if all_ok:
        print("  All selected scripts completed successfully.")
    else:
        print("  Some scripts failed. Review the output above for details.")
    print()


# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("\n  Machine Setup Orchestrator")
    print("  Answer y/n for each component below.\n")

    selected = select_scripts()
    confirm_selection(selected)
    results = run_scripts(selected)
    print_summary(results)
