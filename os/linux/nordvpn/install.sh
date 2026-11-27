#!/usr/bin/bash
# Install the vpnon/vpnoff helpers and keep the NordVPN daemon off at boot
# (vpnon starts it on demand). A sudoers rule lets vpnon/vpnoff start and stop
# the daemon without a password. Asks for sudo to change the system units.
# Safe to re-run. Undo: bash install.sh --uninstall
set -e
cd "$(dirname "$(readlink -f "$0")")"

bin=$HOME/.local/bin
# nordvpnd-killswitch.service is static, pulled in only by nordvpnd.service
units=(nordvpnd.service nordvpnd.socket)
sudoers=/etc/sudoers.d/nordvpn

if [ "${1:-}" = --uninstall ]; then
    rm -f "$bin/vpnon" "$bin/vpnoff"
    sudo rm -f "$sudoers"
    sudo systemctl enable "${units[@]}"
    echo "Uninstalled: helpers and sudoers rule removed, daemon starts at boot again"
    exit 0
fi

command -v nordvpn >/dev/null || {
    echo "Missing: nordvpn" >&2
    exit 1
}

chmod +x vpnon vpnoff
mkdir -p "$bin"
ln -sfn "$PWD/vpnon" "$bin/vpnon"
ln -sfn "$PWD/vpnoff" "$bin/vpnoff"

# Exact command lines only (no wildcards); must match vpnon/vpnoff word for word
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
cat >"$tmp" <<EOF
$(id -un) ALL=(root) NOPASSWD: /usr/bin/systemctl start nordvpnd.socket nordvpnd.service, \\
    /usr/bin/systemctl stop nordvpnd.socket nordvpnd.service nordvpnd-killswitch.service
EOF
visudo -cqf "$tmp" || {
    echo "Bad sudoers rule, not installed" >&2
    exit 1
}
sudo install -m 0440 -o root -g root "$tmp" "$sudoers"

# Disable only: a running daemon keeps running until vpnoff or reboot
sudo systemctl disable "${units[@]}"
echo "Done: vpnon/vpnoff installed (no password), NordVPN daemon no longer starts at boot"
