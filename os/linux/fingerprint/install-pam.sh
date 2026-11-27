#!/usr/bin/bash
# Fingerprint at the login screen, and a notification when sudo waits for a finger
# without a terminal (see README.md). ASUS laptop only. Run as root:
#   sudo bash install-pam.sh               install
#   sudo bash install-pam.sh --uninstall   back to Fedora's defaults
set -e
[ "$(id -u)" = 0 ] || {
    echo "Run as root: sudo bash install-pam.sh" >&2
    exit 1
}
here=$(cd "$(dirname "$0")" && pwd)
notify=/usr/local/libexec/fingerprint-sudo-notify

# Drop our pam_exec lines from /etc/pam.d/sudo (matched by the script path)
sed -i "\#pam_exec.so.* $notify#d" /etc/pam.d/sudo

if [ "${1:-}" = --uninstall ]; then
    rm -f /etc/pam.d/plasmalogin "$notify" # /usr/lib/pam.d/plasmalogin takes over
    echo "Uninstalled"
    exit 0
fi

lsusb -d 2808:a658 >/dev/null || {
    echo "No FT9366 sensor (2808:a658) on this machine" >&2
    exit 1
}

install -m 644 "$here/pam/plasmalogin" /etc/pam.d/plasmalogin
install -m 755 "$here/pam/sudo-notify" "$notify"
restorecon /etc/pam.d/plasmalogin "$notify"

# Notify before system-auth runs pam_fprintd; close it once sudo opens its session.
# seteuid: pam_exec otherwise runs the script with sudo's real uid (the user), not root
sed -i -e "0,/^auth/s##auth       optional     pam_exec.so quiet seteuid $notify\n&#" \
    -e "0,/^session/s##session    optional     pam_exec.so quiet seteuid $notify\n&#" \
    /etc/pam.d/sudo
cat /etc/pam.d/sudo
