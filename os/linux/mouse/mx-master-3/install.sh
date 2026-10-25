#!/usr/bin/bash
# Solaar for the Logitech MX Master 3 (see README.md). Laptop only.
# Needs sudo. Safe to re-run. Log out and back in to start it.
# Undo: bash install.sh --uninstall
set -e

if [ "${1:-}" = --uninstall ]; then
    sudo dnf remove -y solaar
    exit 0
fi

# Over Bluetooth it shows up by name; through a Unifying (c52b) or Bolt (c548)
# receiver, the receiver is enough
grep -qs 'MX Master 3' /sys/class/hidraw/*/device/uevent ||
    lsusb -d 046d:c52b >/dev/null || lsusb -d 046d:c548 >/dev/null ||
    { echo "No MX Master 3 found; turn it on and connect it first" >&2; exit 1; }
sudo dnf install -y solaar
echo "Done; Solaar starts at login (tray icon). Set the buttons up in its rule editor"
