#!/usr/bin/env python3
"""
Drive push setup
Installs rclone, puts `drive-push` on the PATH and signs in the gdrive-rw remote.
Run with: python os/windows/drive-mirror/install.py [--uninstall]
"""

import ctypes
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
PUSH_SCRIPT = HERE / "drive-push.ps1"
LOCALAPPDATA = Path.home() / "AppData" / "Local"
# No winget on LTSC, so install from the GitHub release instead
RCLONE_RELEASE_API = "https://api.github.com/repos/rclone/rclone/releases/latest"
RCLONE_DIR = LOCALAPPDATA / "Programs" / "rclone"
BIN_DIR = LOCALAPPDATA / "levves" / "bin"
SHIM = BIN_DIR / "drive-push.cmd"
REMOTE = "gdrive-rw"
TASK_NAME = "drive-push"
TASK_EVERY_HOURS = 3
DISK_LABEL = "Drive Mirror"

# ── Helpers ───────────────────────────────────────────────────────────────────

def print_header(title):
    print(f"\n{'─' * 50}")
    print(f"  {title}")
    print(f"{'─' * 50}")

def fail(msg):
    print(f"  ✗ {msg}")
    sys.exit(1)

def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "levves-setup-drive-mirror"})
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)

def rclone_exe():
    return RCLONE_DIR / "rclone.exe"

def installed_version():
    if not rclone_exe().exists():
        return None
    out = subprocess.run([str(rclone_exe()), "version"], capture_output=True, text=True).stdout
    return out.split()[1] if out else None   # "rclone v1.71.0 ..."

def broadcast_env_change():
    # Lets new terminals and Explorer pick up the PATH change without signing out
    HWND_BROADCAST, WM_SETTINGCHANGE, SMTO_ABORTIFHUNG = 0xFFFF, 0x1A, 0x2
    ctypes.windll.user32.SendMessageTimeoutW(
        HWND_BROADCAST, WM_SETTINGCHANGE, 0, "Environment", SMTO_ABORTIFHUNG, 5000, None)

def edit_user_path(add=(), remove=()):
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment", 0,
                        winreg.KEY_READ | winreg.KEY_SET_VALUE) as key:
        try:
            value, kind = winreg.QueryValueEx(key, "Path")
        except FileNotFoundError:
            value, kind = "", winreg.REG_EXPAND_SZ
        parts = [p for p in value.split(";") if p]
        lower = {p.lower().rstrip("\\") for p in parts}
        changed = False
        for p in map(str, add):
            if p.lower() not in lower:
                parts.append(p)
                changed = True
        for p in map(str, remove):
            kept = [x for x in parts if x.lower().rstrip("\\") != p.lower()]
            changed |= len(kept) != len(parts)
            parts = kept
        if changed:
            winreg.SetValueEx(key, "Path", 0, kind, ";".join(parts))
            broadcast_env_change()
    return changed

# ── Steps ─────────────────────────────────────────────────────────────────────

def check_disk():
    print_header("Checking the Drive Mirror disk")
    out = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         f"(Get-Volume | Where-Object FileSystemLabel -eq '{DISK_LABEL}').DriveLetter"],
        capture_output=True, text=True).stdout.strip()
    if not out:
        fail(f"No disk labeled '{DISK_LABEL}' here; this is for the desktop only.")
    print(f"  ✓ Found it at {out}:")

def install_rclone():
    print_header("Installing rclone")
    try:
        release = fetch_json(RCLONE_RELEASE_API)
    except Exception as e:
        fail(f"Could not reach GitHub: {e}")

    tag = release["tag_name"]
    if installed_version() == tag:
        print(f"  ✓ rclone {tag} is already installed, skipping.")
        return

    asset = next((a for a in release["assets"]
                  if a["name"].endswith("-windows-amd64.zip")), None)
    if not asset:
        fail(f"No windows-amd64 zip in rclone release {tag}.")
    expected = (asset.get("digest") or "").removeprefix("sha256:")
    if not expected:
        fail(f"GitHub gave no sha256 for {asset['name']}, refusing to use it.")

    print(f"  Downloading {asset['name']}...")
    tmp = Path(tempfile.mkdtemp())
    archive = tmp / asset["name"]
    urllib.request.urlretrieve(asset["browser_download_url"], archive)
    actual = hashlib.sha256(archive.read_bytes()).hexdigest()
    if actual != expected:
        fail(f"sha256 mismatch for {asset['name']}:\n      expected {expected}\n      got      {actual}")
    print("  ✓ sha256 matches the GitHub release.")

    with zipfile.ZipFile(archive) as z:
        member = next(n for n in z.namelist() if n.endswith("/rclone.exe"))
        RCLONE_DIR.mkdir(parents=True, exist_ok=True)
        with z.open(member) as src, open(rclone_exe(), "wb") as dst:
            shutil.copyfileobj(src, dst)
    shutil.rmtree(tmp, ignore_errors=True)
    print(f"  ✓ rclone {tag} installed to {RCLONE_DIR}")

def install_shim():
    print_header("Putting drive-push on the PATH")
    BIN_DIR.mkdir(parents=True, exist_ok=True)
    # Absolute path to the repo at install time: re-run if the repo moves
    SHIM.write_text(
        "@powershell -NoProfile -ExecutionPolicy Bypass "
        f"-File \"{PUSH_SCRIPT.resolve()}\" %*\r\n", encoding="ascii")
    print(f"  ✓ {SHIM}")
    if edit_user_path(add=[RCLONE_DIR, BIN_DIR]):
        print("  ✓ Added rclone and levves\\bin to the user PATH (open a new terminal).")
    else:
        print("  ✓ Already on the user PATH.")

def create_remote():
    print_header(f"Google Drive remote ({REMOTE})")
    remotes = subprocess.run([str(rclone_exe()), "listremotes"],
                             capture_output=True, text=True).stdout.split()
    if f"{REMOTE}:" in remotes:
        print(f"  ✓ {REMOTE} already exists, skipping.")
        return
    # Write access, unlike the Linux read-only `gdrive` remote
    print("  Sign in to Google in the browser window that opens...")
    # stdout is the new config section, token included: keep it off the screen.
    # The sign-in link goes to stderr and still shows.
    result = subprocess.run([str(rclone_exe()), "config", "create", REMOTE, "drive", "scope=drive"],
                            stdout=subprocess.DEVNULL)
    if result.returncode != 0:
        fail("rclone config create failed.")
    print(f"  ✓ {REMOTE} created.")

def register_task():
    print_header("Scheduled task")
    # conhost --headless runs PowerShell with no window flashing up every few hours
    ps = f"""
$ErrorActionPreference = 'Stop'
$action = New-ScheduledTaskAction -Execute 'conhost.exe' `
    -Argument '--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{PUSH_SCRIPT.resolve()}"'
$logon = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$logon.Delay = 'PT10M'
$every = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
    -RepetitionInterval (New-TimeSpan -Hours {TASK_EVERY_HOURS})
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 4)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName '{TASK_NAME}' -Action $action -Trigger $logon,$every `
    -Settings $settings -Principal $principal -Force | Out-Null
"""
    result = subprocess.run(["powershell", "-NoProfile", "-Command", ps])
    if result.returncode != 0:
        fail(f"Could not register the {TASK_NAME} task.")
    print(f"  ✓ '{TASK_NAME}' runs 10 min after logon and every {TASK_EVERY_HOURS} hours.")

def uninstall():
    print_header("Removing drive-push")
    subprocess.run(["powershell", "-NoProfile", "-Command",
                    f"Unregister-ScheduledTask -TaskName '{TASK_NAME}' -Confirm:$false "
                    "-ErrorAction SilentlyContinue"])
    SHIM.unlink(missing_ok=True)
    shutil.rmtree(RCLONE_DIR, ignore_errors=True)
    edit_user_path(remove=[RCLONE_DIR, BIN_DIR] if not any(BIN_DIR.glob("*")) else [RCLONE_DIR])
    print("  ✓ Removed the task, rclone, the drive-push shim and their PATH entries.")
    print(f"    The {REMOTE} remote stays in rclone's config (%APPDATA%\\rclone\\rclone.conf).")

def done():
    print_header("Drive push setup complete")
    print("  In a new terminal:")
    print("    drive-push --dry-run   # list what would upload")
    print("    drive-push             # upload it")
    print()

# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("\n  Drive push setup")
    if "--uninstall" in sys.argv:
        uninstall()
        sys.exit(0)
    check_disk()
    install_rclone()
    install_shim()
    create_remote()
    register_task()
    done()
