#!/usr/bin/env python3
"""
Dev Environment Setup Script
Installs VS Code extensions.
Run with: python os/windows/vscode/install.py
"""

import subprocess
import sys
from pathlib import Path

# ── Config ────────────────────────────────────────────────────────────────────

EXTENSIONS = [
    # ── Core ──────────────────────────────────────────────────────────────────
    "anthropic.claude-code",
    "esbenp.prettier-vscode",
    "dbaeumer.vscode-eslint",

    # ── TypeScript & React ─────────────────────────────────────────────────── 
    "yoavbls.pretty-ts-errors",
    "formulahendry.auto-rename-tag",
    "wix.vscode-import-cost",
    "christian-kohler.path-intellisense",
    "unifiedjs.vscode-mdx",

    # ── Tailwind ──────────────────────────────────────────────────────────────
    "bradlc.vscode-tailwindcss",

    # ── Storybook ─────────────────────────────────────────────────────────────
    "storybook.storybook-vscode",

    # ── Testing ───────────────────────────────────────────────────────────────
    "firsttris.vscode-jest-runner",
    "ms-playwright.playwright",

    # ── Visibility & Orientation ──────────────────────────────────────────────
    "usernamehw.errorlens",
    "oderwat.indent-rainbow",
    "pkief.material-icon-theme",
    "lucafalasco.matcha",

    # ── Git ───────────────────────────────────────────────────────────────────
    "eamodio.gitlens",
    "github.vscode-pull-request-github",

    # ── Design & Tooling ──────────────────────────────────────────────────────
    "figma.figma-vscode-extension",
    "pflannery.vscode-versionlens",
    "streetsidesoftware.code-spell-checker",
    "editorconfig.editorconfig",

    # ── Platform ──────────────────────────────────────────────────────────────
    "ms-vscode-remote.remote-wsl",
    "nrwl.angular-console",
    "swmansion.react-native-ide",
    "thqby.vscode-autohotkey2-lsp",
]

# ── Helpers ───────────────────────────────────────────────────────────────────

def print_header(title):
    print(f"\n{'─' * 50}")
    print(f"  {title}")
    print(f"{'─' * 50}")

def run(cmd):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.returncode == 0, result.stdout.strip(), result.stderr.strip()

# ── Steps ─────────────────────────────────────────────────────────────────────

def check_code_cli():
    print_header("Checking VS Code CLI")
    ok, out, _ = run("code --version")
    if ok:
        print(f"  ✓ VS Code found: {out.splitlines()[0]}")
    else:
        print("  ✗ VS Code CLI not found. Make sure 'code' is in your PATH.")
        print("    In VS Code: Ctrl+Shift+P → 'Shell Command: Install code in PATH'")
        sys.exit(1)

def install_extensions():
    print_header(f"Installing {len(EXTENSIONS)} VS Code Extensions")
    failed = []
    for ext in EXTENSIONS:
        ok, _, err = run(f"code --install-extension {ext} --force")
        status = "✓" if ok else "✗"
        print(f"  {status} {ext}")
        if not ok:
            failed.append((ext, err))
    if failed:
        print(f"\n  {len(failed)} extension(s) failed:")
        for ext, err in failed:
            print(f"    - {ext}: {err}")
    else:
        print(f"\n  All extensions installed successfully.")

def done():
    print_header("Setup Complete")
    print("  Restart VS Code to apply all changes.")
    print("  Sign into Settings Sync to pull your settings: Ctrl+Shift+P → Settings Sync: Turn On")
    print()

# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("\n  Dev Environment Setup")
    check_code_cli()
    install_extensions()
    done()
