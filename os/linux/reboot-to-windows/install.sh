#!/usr/bin/bash
# Install reboot-to-windows (see README.md). Desktop only (dual boot with
# Windows). Copies the root helper to /usr/local/sbin, adds a sudoers rule for
# it alone, and links the launcher into the app menu. Safe to re-run.
# Undo: bash install.sh --uninstall
set -e
cd "$(dirname "$(readlink -f "$0")")"
. ../lib/install.sh

helper=/usr/local/sbin/efi-bootnext-windows
rule=/etc/sudoers.d/reboot-to-windows
bin=$local_bin/reboot-to-windows
app=$apps/reboot-to-windows.desktop

if [ "${1:-}" = --uninstall ]; then
    sudo rm -f "$helper" "$rule"
    rm -f "$bin" "$app"
    echo "Uninstalled"
    exit 0
fi

[ -d /sys/firmware/efi ] || {
    echo "Not booted in UEFI mode" >&2
    exit 1
}
efibootmgr | grep -q 'Windows Boot Manager' || {
    echo "No Windows Boot Manager UEFI entry on this machine" >&2
    exit 1
}

# The helper runs as root without a password, so it's a root-owned copy,
# never a link into this user-writable repo
sudo install -o root -g root -m 755 efi-bootnext-windows "$helper"
tmp=$(mktemp)
echo "$USER ALL=(root) NOPASSWD: $helper" >"$tmp"
visudo -cqf "$tmp"
sudo install -o root -g root -m 440 "$tmp" "$rule"
rm -f "$tmp"

link reboot-to-windows "$bin"
link reboot-to-windows.desktop "$app"
echo "Done. 'Reboot to Windows' is in the app menu (and KRunner); 'reboot-to-windows' in a terminal."
