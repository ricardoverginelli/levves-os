#!/usr/bin/env python3
"""
Leaves Theme Setup Script
Applies the Leaves look (os/linux/plasma/DESIGN.md) to Windows: dark mode with glass,
the amber accent, the leaves wallpaper on desktop and lock screen, a minimal taskbar,
and the Leaves terminal colors with JetBrains Mono in console windows.
Run with: python os/windows/theme/install.py
"""

import ctypes
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import winreg
import zipfile
from pathlib import Path

# ── Config ────────────────────────────────────────────────────────────────────

# The Plasma theme is the source of truth; colors and wallpaper come from it
PLASMA_DIR = Path(__file__).resolve().parents[2] / "linux" / "plasma"
PALETTE_FILE = PLASMA_DIR / "palette.json"
WALLPAPER_SRC = PLASMA_DIR / "wallpaper" / "leaves.png"
# Windows keeps pointing at the wallpaper file, so use a copy outside the repo
WALLPAPER = Path(os.environ["LOCALAPPDATA"]) / "Leaves" / "leaves.png"

PERSONALIZE_KEY = r"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
DWM_KEY = r"Software\Microsoft\Windows\DWM"
ACCENT_KEY = r"Software\Microsoft\Windows\CurrentVersion\Explorer\Accent"
ADVANCED_KEY = r"Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
SEARCH_KEY = r"Software\Microsoft\Windows\CurrentVersion\Search"
DESKTOP_KEY = r"Control Panel\Desktop"
CONTENT_KEY = r"Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
CONSOLE_KEY = "Console"
FONTS_KEY = r"Software\Microsoft\Windows NT\CurrentVersion\Fonts"

# JetBrains Mono, the Leaves mono font. The release predates GitHub's asset digests,
# so its sha256 was pinned on first install (2026-10-28); bump both together
FONT_URL = "https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
FONT_SHA256 = "6f6376c6ed2960ea8a963cd7387ec9d76e3f629125bc33d1fdcd7eb7012f7bbf"
FONT_FILES = {
    "JetBrainsMono-Regular.ttf": "JetBrains Mono Regular (TrueType)",
    "JetBrainsMono-Bold.ttf": "JetBrains Mono Bold (TrueType)",
    "JetBrainsMono-Italic.ttf": "JetBrains Mono Italic (TrueType)",
    "JetBrainsMono-BoldItalic.ttf": "JetBrains Mono Bold Italic (TrueType)",
}
USER_FONTS = Path(os.environ["LOCALAPPDATA"]) / "Microsoft" / "Windows" / "Fonts"

# Console values this script owns. Per-program subkeys under HKCU\Console get them
# removed so every console falls back to the Leaves defaults
CONSOLE_VALUES = [f"ColorTable{i:02d}" for i in range(16)] + [
    "ScreenColors", "PopupColors", "CursorColor",
    "FaceName", "FontFamily", "FontSize", "FontWeight",
]
# Shortcuts can carry their own console settings (PowerShell's blue comes from its
# Start menu shortcut): an extra data block of 0xCC bytes, signature 0xA0000002
LNK_CONSOLE_BLOCK = bytes.fromhex("cc000000020000a0")
LNK_CONSOLE_BLOCK_SIZE = 0xCC
SHORTCUT_DIRS = [
    Path(os.environ["APPDATA"]) / "Microsoft" / "Windows" / "Start Menu",
    Path(os.environ["APPDATA"]) / "Microsoft" / "Internet Explorer" / "Quick Launch",
    Path(os.environ["ProgramData"]) / "Microsoft" / "Windows" / "Start Menu",
]
SHORTCUT_BACKUP = Path(os.environ["LOCALAPPDATA"]) / "Leaves" / "shortcut-backup"

# ── Helpers ───────────────────────────────────────────────────────────────────

def print_header(title):
    print(f"\n{'─' * 50}")
    print(f"  {title}")
    print(f"{'─' * 50}")

def set_value(path, name, kind, value):
    with winreg.CreateKeyEx(winreg.HKEY_CURRENT_USER, path, 0, winreg.KEY_SET_VALUE) as key:
        winreg.SetValueEx(key, name, 0, kind, value)

def set_dword(path, name, value):
    set_value(path, name, winreg.REG_DWORD, value)

def rgb(hex_color):
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def mix(color, target, amount):
    """Move color toward target by amount (0-1), like DESIGN.md's bright/faint variants."""
    return tuple(round(c + (t - c) * amount) for c, t in zip(color, target))

def abgr(color, alpha=0xFF):
    """DWORD as Windows stores accent colors: 0xAABBGGRR."""
    r, g, b = color
    return alpha << 24 | b << 16 | g << 8 | r

def clear_values(key_path, names):
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key_path, 0, winreg.KEY_SET_VALUE) as key:
        for name in names:
            try:
                winreg.DeleteValue(key, name)
            except FileNotFoundError:
                pass

def broadcast_setting_change(area):
    """Tell running apps a setting changed (WM_SETTINGCHANGE), so they repaint."""
    ctypes.windll.user32.SendMessageTimeoutW(
        0xFFFF, 0x001A, 0, area, 0x0002, 5000, ctypes.byref(ctypes.c_ulong())
    )

# ── Steps ─────────────────────────────────────────────────────────────────────

def load_palette():
    print_header("Loading Leaves Palette")
    for path in (PALETTE_FILE, WALLPAPER_SRC):
        if not path.exists():
            print(f"  ✗ Not found: {path}")
            print("    The theme reads its colors and wallpaper from os/linux/plasma/.")
            sys.exit(1)
    palette = json.loads(PALETTE_FILE.read_text())
    print(f"  ✓ Palette loaded, accent {palette['accent']}")
    return palette

def apply_dark_mode():
    print_header("Dark Mode and Glass")
    set_dword(PERSONALIZE_KEY, "AppsUseLightTheme", 0)
    set_dword(PERSONALIZE_KEY, "SystemUsesLightTheme", 0)
    # Glass is the Leaves default for anything floating (DESIGN.md, Translucency)
    set_dword(PERSONALIZE_KEY, "EnableTransparency", 1)
    print("  ✓ Dark apps and system, transparency on.")

def apply_accent(palette):
    print_header("Amber Accent")
    accent = rgb(palette["accent"])
    white, black = (255, 255, 255), (0, 0, 0)

    # Windows derives its accent shades from this 8-slot palette (light3..dark3, unused).
    # Dark mode draws accented text and controls with the light shades, so they stay amber.
    shades = [
        mix(accent, white, 0.55),
        mix(accent, white, 0.35),
        rgb(palette["accent-hover"]),
        accent,
        rgb(palette["accent-pressed"]),
        mix(accent, black, 0.40),
        mix(accent, black, 0.60),
        mix(accent, black, 0.60),
    ]
    set_value(ACCENT_KEY, "AccentPalette", winreg.REG_BINARY,
              bytes(b for color in shades for b in (*color, 0)))
    set_dword(ACCENT_KEY, "AccentColorMenu", abgr(accent))
    set_dword(ACCENT_KEY, "StartColorMenu", abgr(shades[5]))
    set_dword(DWM_KEY, "AccentColor", abgr(accent))
    # Colorization is stored as ARGB, not ABGR
    r, g, b = accent
    set_dword(DWM_KEY, "ColorizationColor", 0xC4 << 24 | r << 16 | g << 8 | b)
    set_dword(DWM_KEY, "ColorizationAfterglow", 0xC4 << 24 | r << 16 | g << 8 | b)
    # Never pick the accent from the wallpaper
    set_dword(DESKTOP_KEY, "AutoColorization", 0)

    # One accented thing per view: no accent on title bars, borders, taskbar or Start
    set_dword(DWM_KEY, "ColorPrevalence", 0)
    set_dword(PERSONALIZE_KEY, "ColorPrevalence", 0)
    print(f"  ✓ Accent {palette['accent']}, kept off title bars and the taskbar.")

def apply_taskbar():
    print_header("Taskbar")
    # Leaves has no taskbar, only a launcher at the top left; the closest Windows
    # gets is a left-aligned bar with nothing but the Start button and pinned apps
    settings = [
        (ADVANCED_KEY, "TaskbarAl", 0, "left-aligned"),
        (ADVANCED_KEY, "ShowTaskViewButton", 0, "Task View hidden"),
        (ADVANCED_KEY, "ShowCopilotButton", 0, "Copilot hidden"),
        (ADVANCED_KEY, "TaskbarDa", 0, "Widgets hidden"),
        (SEARCH_KEY, "SearchboxTaskbarMode", 0, "search box hidden"),
    ]
    for path, name, value, label in settings:
        try:
            set_dword(path, name, value)
            print(f"  ✓ {label}")
        except PermissionError:
            # Windows guards some of these from scripts (TaskbarDa on 24H2). Not an
            # error: LTSC has no Widgets anyway, elsewhere it's a toggle in Settings
            print(f"  – {label}: skipped, Windows protects it (Settings → Personalization → Taskbar)")

def apply_wallpaper():
    print_header("Wallpaper")
    WALLPAPER.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(WALLPAPER_SRC, WALLPAPER)

    # Fill: covers the screen, cropping the edges that don't fit
    set_value(DESKTOP_KEY, "WallpaperStyle", winreg.REG_SZ, "10")
    set_value(DESKTOP_KEY, "TileWallpaper", winreg.REG_SZ, "0")
    # SPI_SETDESKWALLPAPER, saved to the profile and broadcast
    if not ctypes.windll.user32.SystemParametersInfoW(0x0014, 0, str(WALLPAPER), 0x01 | 0x02):
        print("  ✗ Could not set the desktop wallpaper.")
        sys.exit(1)
    print(f"  ✓ Desktop: {WALLPAPER}")

    # Lock screen (the sign-in screen shows it too). The WinRT LockScreen API sets it
    # for this user the same way Settings does, with no policy behind it
    lock_script = f"""
        Add-Type -AssemblyName System.Runtime.WindowsRuntime
        $null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
        $null = [Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime]
        $asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {{
            $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 }}
        $opTask = ($asTask | Where-Object {{ $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' }})[0]
        $actTask = ($asTask | Where-Object {{ $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' }})[0]
        $file = $opTask.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke($null,
            @([Windows.Storage.StorageFile]::GetFileFromPathAsync('{WALLPAPER}')))
        $file.Wait()
        $actTask.Invoke($null, @([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($file.Result))).Wait()
    """
    result = subprocess.run(
        ["powershell", "-NoProfile", "-NonInteractive", "-Command", lock_script],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print("  ✗ Could not set the lock screen:")
        print(f"    {result.stderr.strip()}")
        sys.exit(1)

    # A still picture: no Spotlight rotation and no tips or "fun facts" over it
    set_dword(CONTENT_KEY, "RotatingLockScreenEnabled", 0)
    set_dword(CONTENT_KEY, "RotatingLockScreenOverlayEnabled", 0)
    set_dword(CONTENT_KEY, "SubscribedContent-338387Enabled", 0)
    print("  ✓ Lock and sign-in screen, without Spotlight or tips.")

def install_font():
    print_header("JetBrains Mono")
    USER_FONTS.mkdir(parents=True, exist_ok=True)

    if all((USER_FONTS / name).exists() for name in FONT_FILES):
        print("  ✓ Already installed, skipping download.")
    else:
        print("  Downloading JetBrains Mono...")
        archive = Path(tempfile.mkdtemp()) / "JetBrainsMono.zip"
        urllib.request.urlretrieve(FONT_URL, archive)
        actual = hashlib.sha256(archive.read_bytes()).hexdigest()
        if actual != FONT_SHA256:
            print("  ✗ sha256 mismatch for JetBrains Mono:")
            print(f"      expected {FONT_SHA256}")
            print(f"      got      {actual}")
            sys.exit(1)
        print("  ✓ sha256 matches the pinned release.")
        with zipfile.ZipFile(archive) as z:
            for name in FONT_FILES:
                (USER_FONTS / name).write_bytes(z.read(f"fonts/ttf/{name}"))

    # Per-user install, the same as "Install" (not "for all users") in the font viewer
    for name, display in FONT_FILES.items():
        set_value(FONTS_KEY, display, winreg.REG_SZ, str(USER_FONTS / name))
        ctypes.windll.gdi32.AddFontResourceW(str(USER_FONTS / name))
    # WM_FONTCHANGE, so running apps see the new font
    ctypes.windll.user32.SendMessageTimeoutW(
        0xFFFF, 0x001D, 0, 0, 0x0002, 5000, ctypes.byref(ctypes.c_ulong())
    )
    print(f"  ✓ Installed for this user in {USER_FONTS}")

def apply_console(palette):
    print_header("Console Colors")
    t = palette["terminal"]
    white = (255, 255, 255)

    # The Yakuake scheme's ANSI colors (yakuake/build.py), in console table order:
    # black, blue, green, cyan, red, magenta, yellow, white. Slot 0 is also the
    # console's background, so black is bg here rather than raised
    normal = [palette["bg"], palette["info"], palette["success"], t["cyan"],
              palette["critical"], t["magenta"], palette["warning"], palette["text"]]
    table = [rgb(c) for c in normal]
    # Bright variants are 25% toward white; bright black is text-faint
    table += [rgb(t["bright-black"])] + [mix(c, white, 0.25) for c in table[1:]]

    for i, color in enumerate(table):
        set_dword(CONSOLE_KEY, f"ColorTable{i:02d}", abgr(color, alpha=0))
    set_dword(CONSOLE_KEY, "ScreenColors", 0x07)   # text on bg
    set_dword(CONSOLE_KEY, "PopupColors", 0x70)    # bg on text (high nibble is the background)
    set_dword(CONSOLE_KEY, "CursorColor", abgr(rgb(palette["accent"]), alpha=0))
    set_value(CONSOLE_KEY, "FaceName", winreg.REG_SZ, "JetBrains Mono")
    set_dword(CONSOLE_KEY, "FontFamily", 0x36)     # TrueType, fixed pitch, modern
    set_dword(CONSOLE_KEY, "FontSize", 16 << 16)   # 16px tall, width from the font
    set_dword(CONSOLE_KEY, "FontWeight", 400)
    print("  ✓ Leaves colors, amber cursor and JetBrains Mono as the console defaults.")

    # Per-program overrides (PowerShell ships with its own blue) fall back to the defaults
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, CONSOLE_KEY) as key:
        subkeys = [winreg.EnumKey(key, i) for i in range(winreg.QueryInfoKey(key)[0])]
    for subkey in subkeys:
        clear_values(rf"{CONSOLE_KEY}\{subkey}", CONSOLE_VALUES)
        print(f"  ✓ Override cleared: {subkey}")

    # Shortcuts with console settings of their own: drop that block so they use the
    # defaults too. Originals are kept in the backup folder the first time
    for folder in SHORTCUT_DIRS:
        for shortcut in folder.rglob("*.lnk"):
            data = shortcut.read_bytes()
            at = data.find(LNK_CONSOLE_BLOCK)
            if at < 0:
                continue
            backup = SHORTCUT_BACKUP / shortcut.relative_to(folder.parent)
            try:
                if not backup.exists():
                    backup.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(shortcut, backup)
                shortcut.write_bytes(data[:at] + data[at + LNK_CONSOLE_BLOCK_SIZE:])
                print(f"  ✓ Shortcut reset: {shortcut.relative_to(folder.parent)}")
            except PermissionError:
                print(f"  – Shortcut skipped (needs admin): {shortcut}")
    print("  New console windows open with the Leaves look; open ones keep theirs.")

def refresh():
    print_header("Applying")
    broadcast_setting_change("ImmersiveColorSet")
    broadcast_setting_change("WindowsThemeElement")
    broadcast_setting_change("TraySettings")
    print("  ✓ Running apps notified.")

def done():
    print_header("Theme Setup Complete")
    print("  Some apps only pick up dark mode when they restart.")
    print("  If the taskbar hasn't updated, sign out and back in.")
    print()

# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("\n  Leaves Theme Setup")
    palette = load_palette()
    apply_dark_mode()
    apply_accent(palette)
    apply_taskbar()
    apply_wallpaper()
    install_font()
    apply_console(palette)
    refresh()
    done()
