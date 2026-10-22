#!/usr/bin/bash
# Install drive-mirror (see README.md). Desktop only (needs the "Drive Mirror"
# HDD, NTFS UUID C4C236E9C236DF7C). User-level; the fstab line and the rclone
# remote are set up once by hand, as README.md describes. Safe to re-run.
# Undo: bash install.sh --uninstall (leaves the disk, fstab and rclone config alone)
set -e
cd "$(dirname "$(readlink -f "$0")")"

bin=$HOME/.local/bin/drive-mirror
units=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user

if [ "${1:-}" = --uninstall ]; then
    systemctl --user disable --now drive-mirror.timer 2>/dev/null || true
    rm -f "$bin" "$units/drive-mirror.service" "$units/drive-mirror.timer"
    systemctl --user daemon-reload
    echo "Uninstalled"
    exit 0
fi

[ -e /dev/disk/by-uuid/C4C236E9C236DF7C ] || { echo "No Drive Mirror HDD on this machine" >&2; exit 1; }
command -v rclone >/dev/null || { echo "Missing rclone: sudo dnf install rclone"; exit 1; }
grep -q C4C236E9C236DF7C /etc/fstab || echo "Note: the fstab line from README.md is missing"
rclone listremotes | grep -qx gdrive: || echo "Note: no 'gdrive' rclone remote yet (see README.md)"

mkdir -p "$(dirname "$bin")" "$units"
ln -sfn "$PWD/drive-mirror" "$bin"
ln -sfn "$PWD/drive-mirror.service" "$units/drive-mirror.service"
ln -sfn "$PWD/drive-mirror.timer" "$units/drive-mirror.timer"
systemctl --user daemon-reload
systemctl --user enable --now drive-mirror.timer
echo "Done. Daily sync enabled; run 'drive-mirror --dry-run' to preview one."
