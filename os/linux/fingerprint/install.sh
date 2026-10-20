#!/usr/bin/bash
# Install the libfprint that build.sh made and stop dnf replacing it (see README.md).
# ASUS laptop only (needs the 2808:a658 sensor). Run as root: sudo bash install.sh
# Undo: sudo bash install.sh --uninstall (back to Fedora's libfprint)
set -e
[ "$(id -u)" = 0 ] || { echo "Run as root: sudo bash install.sh" >&2; exit 1; }

user=${SUDO_USER:-$USER}
out=$(getent passwd "$user" | cut -d: -f6)/.cache/libfprint-ft9366
conf=/etc/dnf/libdnf5.conf.d/90-libfprint-ft9366.conf

if [ "${1:-}" = --uninstall ]; then
    rm -f "$conf"
    dnf -y distro-sync libfprint
    systemctl stop fprintd || true
    echo "Uninstalled"
    exit 0
fi

lsusb -d 2808:a658 >/dev/null || { echo "No FT9366 sensor (2808:a658) on this machine" >&2; exit 1; }
rpm=$(ls "$out"/libfprint-[0-9]*.x86_64.rpm 2>/dev/null | tail -1)
[ -n "$rpm" ] || { echo "Nothing built in $out; run bash build.sh first" >&2; exit 1; }

dnf -y --setopt=disable_excludes='*' install "$rpm"
# A newer Fedora libfprint would drop the driver; build.sh again picks that one up
printf '[main]\nexcludepkgs=libfprint\n' >"$conf"
# fprintd is D-Bus activated; the next caller starts it with the new library
systemctl stop fprintd || true
rpm -q libfprint
