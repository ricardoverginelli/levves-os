#!/usr/bin/bash
# Install drive-mirror (see README.md). Desktop only (needs the "Drive Mirror"
# HDD, NTFS UUID C4C236E9C236DF7C). User-level; the fstab line and the rclone
# remote are set up once by hand, as README.md describes. Safe to re-run.
# Undo: bash install.sh --uninstall (leaves the disk, fstab and rclone config alone)
set -e
cd "$(dirname "$(readlink -f "$0")")"
. ../lib/install.sh

bin=$local_bin/drive-mirror

if [ "${1:-}" = --uninstall ]; then
    unlink_units drive-mirror.timer drive-mirror.service
    rm -f "$bin"
    echo "Uninstalled"
    exit 0
fi

[ -e /dev/disk/by-uuid/C4C236E9C236DF7C ] || {
    echo "No Drive Mirror HDD on this machine" >&2
    exit 1
}
need rclone
grep -q C4C236E9C236DF7C /etc/fstab || echo "Note: the fstab line from README.md is missing"
rclone listremotes | grep -qx gdrive: || echo "Note: no 'gdrive' rclone remote yet (see README.md)"

link drive-mirror "$bin"
link_units drive-mirror.service drive-mirror.timer
systemctl --user enable --now drive-mirror.timer
echo "Done. Daily sync enabled; run 'drive-mirror --dry-run' to preview one."
