#!/usr/bin/env python3
"""
Drop-down Terminal Setup Script
Yakuake on Windows: a portable Windows Terminal in the Levves colors, docked on the left and
slid in and out by dropdown.ahk (Win+/ toggles, Win+N new tab, Win+Shift+N Claude Code tab).
Run with: python os/windows/dropdown/install.py   (--uninstall to undo)
"""

import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import winreg
import zipfile
from pathlib import Path

# ── Config ────────────────────────────────────────────────────────────────────

HERE = Path(__file__).parent
REPO = HERE.resolve().parents[2]
TOKENS_DIR = REPO / "design" / "dist"  # levves_tokens.py, the Levves colors and motion
AHK_SCRIPT = HERE / "dropdown.ahk"
# LTSC has no Store, so the portable build from the GitHub release
RELEASE_API = "https://api.github.com/repos/microsoft/terminal/releases/latest"
TERMINAL_DIR = Path.home() / "AppData" / "Local" / "levves" / "terminal"
SETTINGS = TERMINAL_DIR / "settings" / "settings.json"  # where portable mode keeps them
VERSION_FILE = TERMINAL_DIR / "levves-version.txt"
STARTUP_REG_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"
STARTUP_REG_NAME = "dropdown-ahk"
USER_FONTS = Path.home() / "AppData" / "Local" / "Microsoft" / "Windows" / "Fonts"

# Windows Terminal's own GUIDs for the profiles it generates, so ours replace them
POWERSHELL_GUID = "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}"
CMD_GUID = "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}"
CLAUDE_GUID = "{4c4c6576-7665-7300-8000-436c61756465}"

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


def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "levves-setup-dropdown"})
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)


def terminal_running():
    """True while a WindowsTerminal.exe from TERMINAL_DIR runs (its files are locked)."""
    result = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-Command",
            (
                "Get-Process WindowsTerminal -ErrorAction SilentlyContinue | "
                f"Where-Object Path -like '{TERMINAL_DIR}\\*' | Measure-Object | ForEach-Object Count"
            ),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    return result.stdout.strip() not in ("", "0")


def stop_ahk_script():
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


def mix(color, target, amount):
    """Move a #rrggbb color toward target by amount (0-1), like DESIGN.md's bright variants."""
    a = [int(color[i : i + 2], 16) for i in (1, 3, 5)]
    b = [int(target[i : i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * amount):02x}" for x, y in zip(a, b, strict=False))


def milliseconds(value):
    return int(str(value).removesuffix("ms"))


# ── Steps ─────────────────────────────────────────────────────────────────────


def load_tokens():
    print_header("Loading Levves Tokens")
    if not (TOKENS_DIR / "levves_tokens.py").exists():
        print(f"  ✗ Not found: {TOKENS_DIR / 'levves_tokens.py'}")
        sys.exit(1)
    sys.path.insert(0, str(TOKENS_DIR))
    from levves_tokens import TOKENS, color

    print(f"  ✓ Palette loaded, accent {color('accent')}")
    return TOKENS, color


def install_terminal():
    print_header("Installing Windows Terminal (portable)")
    try:
        release = fetch_json(RELEASE_API)
    except (OSError, ValueError) as e:
        if (TERMINAL_DIR / "wt.exe").exists():
            print(f"  ! Could not reach GitHub ({e}); keeping the installed copy.")
            return
        print(f"  ✗ Could not reach GitHub: {e}")
        sys.exit(1)

    tag = release["tag_name"]
    if (
        (TERMINAL_DIR / "wt.exe").exists()
        and VERSION_FILE.exists()
        and VERSION_FILE.read_text().strip() == tag
    ):
        print(f"  ✓ Windows Terminal {tag} is already installed, skipping.")
        return
    if terminal_running():
        print("  ✗ The drop-down terminal is running; close it (exit every tab) and re-run.")
        sys.exit(1)

    asset = next(
        (
            a
            for a in release["assets"]
            if a["name"].startswith("Microsoft.WindowsTerminal_") and a["name"].endswith("_x64.zip")
        ),
        None,
    )
    if not asset:
        print(f"  ✗ No x64 portable zip in Windows Terminal release {tag}.")
        sys.exit(1)
    expected = (asset.get("digest") or "").removeprefix("sha256:")
    if not expected:
        print(f"  ✗ GitHub gave no sha256 for {asset['name']}, refusing to install it.")
        sys.exit(1)

    print(f"  Downloading {asset['name']}...")
    work = Path(tempfile.mkdtemp())
    archive = work / asset["name"]
    urllib.request.urlretrieve(asset["browser_download_url"], archive)
    actual = hashlib.sha256(archive.read_bytes()).hexdigest()
    if actual != expected:
        print(f"  ✗ sha256 mismatch for {asset['name']}:")
        print(f"      expected {expected}")
        print(f"      got      {actual}")
        sys.exit(1)
    print("  ✓ sha256 matches the GitHub release.")

    unpacked = work / "unpacked"
    with zipfile.ZipFile(archive) as z:
        z.extractall(unpacked)
    # The zip holds one folder, terminal-<version>
    roots = [p for p in unpacked.iterdir() if p.is_dir()]
    source = roots[0] if len(roots) == 1 else unpacked

    # Replace the program files, keep settings/ (portable mode's settings and state)
    TERMINAL_DIR.mkdir(parents=True, exist_ok=True)
    for item in TERMINAL_DIR.iterdir():
        if item.name != "settings":
            shutil.rmtree(item) if item.is_dir() else item.unlink()
    for item in source.iterdir():
        shutil.move(str(item), TERMINAL_DIR / item.name)
    (TERMINAL_DIR / ".portable").touch()  # settings next to the exe, not in AppData
    VERSION_FILE.write_text(tag)
    shutil.rmtree(work, ignore_errors=True)
    print(f"  ✓ Windows Terminal {tag} in {TERMINAL_DIR}")


def write_settings(tokens, color):
    print_header("Terminal Settings")
    if not (USER_FONTS / "JetBrainsMono-Regular.ttf").exists():
        print("  ! JetBrains Mono isn't installed; run python os/windows/theme/install.py for it.")

    # The Yakuake scheme (os/linux/plasma/yakuake/build.py): ANSI from the palette,
    # bright 25% toward white, bright black is the faint text
    names = ["black", "red", "green", "yellow", "blue", "purple", "cyan", "white"]
    normal = [
        color("terminal.black"),
        color("critical"),
        color("success"),
        color("warning"),
        color("info"),
        color("terminal.magenta"),
        color("terminal.cyan"),
        color("text"),
    ]
    scheme = {
        "name": "Levves",
        "background": color("bg"),
        "foreground": color("text"),
        "cursorColor": color("accent"),
        "selectionBackground": color("text-faint"),
    }
    for i, (name, value) in enumerate(zip(names, normal, strict=False)):
        scheme[name] = value
        bright = color("terminal.bright-black") if i == 0 else mix(value, "#ffffff", 0.25)
        scheme["bright" + name[0].upper() + name[1:]] = bright

    profiles = [
        {
            "guid": POWERSHELL_GUID,
            "name": "PowerShell",
            "commandline": r"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo",
            "startingDirectory": "%USERPROFILE%",
            "hidden": False,
        },
        {"guid": CMD_GUID, "hidden": True},
    ]
    claude = shutil.which("claude")
    if claude:
        profiles.append(
            {
                "guid": CLAUDE_GUID,
                "name": "Claude Code",
                "commandline": claude,
                "startingDirectory": "%USERPROFILE%",
                "hidden": False,
            }
        )
    else:
        print(
            "  ! claude isn't on the PATH; no Claude Code profile (Win+Shift+N opens PowerShell)."
        )

    settings = {
        "$help": "Written by levves os/windows/dropdown/install.py; re-run it rather than editing here.",
        "$schema": "https://aka.ms/terminal-profiles-schema",
        "defaultProfile": POWERSHELL_GUID,
        # One window: every wt launch, new tabs included, goes into the drop-down
        "windowingBehavior": "useExisting",
        "firstWindowPreference": "defaultProfile",
        "alwaysOnTop": True,
        "showTabsInTitlebar": True,
        "useAcrylicInTabRow": False,
        "confirmCloseAllTabs": False,
        "startOnUserLogin": False,
        "disabledProfileSources": [
            "Windows.Terminal.Wsl",
            "Windows.Terminal.Azure",
            "Windows.Terminal.PowershellCore",
            "Windows.Terminal.VisualStudio",
            "Windows.Terminal.SshHostGenerator",
        ],
        "theme": "Levves",
        "themes": [
            {
                "name": "Levves",
                "window": {"applicationTheme": "dark", "useMica": False},
                "tabRow": {
                    "background": color("title-bar"),
                    "unfocusedBackground": color("title-bar-inactive"),
                },
                "tab": {
                    "background": color("bg"),
                    "unfocusedBackground": color("title-bar"),
                    "showCloseButton": "hover",
                },
            }
        ],
        "schemes": [scheme],
        "profiles": {
            "defaults": {
                "colorScheme": "Levves",
                "font": {"face": "JetBrains Mono", "size": 12},
                "cursorShape": "filledBox",
                "padding": "8",
                "opacity": 100,
                "useAcrylic": False,
                "closeOnExit": "always",
                "bellStyle": "none",
            },
            "list": profiles,
        },
        # Yakuake's Shift+Left/Right between split terminals (yakuakerc, kwin/yakuake-panes)
        "actions": [
            {"command": {"action": "moveFocus", "direction": "left"}, "keys": "shift+left"},
            {"command": {"action": "moveFocus", "direction": "right"}, "keys": "shift+right"},
        ],
    }
    SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    SETTINGS.write_text(json.dumps(settings, indent=4) + "\n", encoding="utf-8")
    print(
        f"  ✓ Levves scheme, JetBrains Mono, PowerShell{' and Claude Code' if claude else ''} profiles"
    )
    print(f"    {SETTINGS}")


def register_startup(tokens):
    print_header("Registering Startup Entry")
    ahk_exe = find_ahk_exe()
    if not ahk_exe:
        print("  ✗ AutoHotkey v2 isn't installed. Run python os/windows/ahk/install.py first.")
        sys.exit(1)
    # DESIGN.md motion: the large-panel durations, passed in so they aren't copied into the script
    opening = milliseconds(tokens["duration.panel-open"])
    closing = milliseconds(tokens["duration.panel-close"])
    reg_value = f'"{ahk_exe}" "{AHK_SCRIPT.resolve()}" {opening} {closing}'
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, STARTUP_REG_KEY, 0, winreg.KEY_SET_VALUE) as key:
        winreg.SetValueEx(key, STARTUP_REG_NAME, 0, winreg.REG_SZ, reg_value)
    print(f"  ✓ HKCU\\{STARTUP_REG_KEY}\\{STARTUP_REG_NAME}")
    print(f"    {reg_value}")
    # #SingleInstance Force replaces an already running copy
    subprocess.Popen([str(ahk_exe), str(AHK_SCRIPT.resolve()), str(opening), str(closing)])
    print(f"  ✓ {AHK_SCRIPT.name} is running.")


def uninstall():
    print_header("Removing the Drop-down Terminal")
    try:
        with winreg.OpenKey(
            winreg.HKEY_CURRENT_USER, STARTUP_REG_KEY, 0, winreg.KEY_SET_VALUE
        ) as key:
            winreg.DeleteValue(key, STARTUP_REG_NAME)
        print(f"  ✓ Removed startup entry {STARTUP_REG_NAME}")
    except FileNotFoundError:
        print("  ✓ No startup entry to remove")
    stop_ahk_script()
    print(f"  ✓ Stopped {AHK_SCRIPT.name}")
    if terminal_running():
        print(f"  ! The terminal is running; close it, then delete {TERMINAL_DIR}")
    elif TERMINAL_DIR.exists():
        shutil.rmtree(TERMINAL_DIR)
        print(f"  ✓ Removed {TERMINAL_DIR}")
    print()


def done():
    print_header("Drop-down Terminal Installed")
    print("  Win+/          open / retract (focuses it when it's open behind another window)")
    print("  Win+N          new PowerShell tab")
    print("  Win+Shift+N    new Claude Code tab")
    print("  Shift+←/→      between split panes; Ctrl+Tab / Ctrl+Shift+Tab between tabs")
    print()


# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    if "--uninstall" in sys.argv[1:]:
        uninstall()
        sys.exit(0)
    print("\n  Drop-down Terminal Setup")
    tokens, color = load_tokens()
    install_terminal()
    write_settings(tokens, color)
    register_startup(tokens)
    done()
