#!/usr/bin/bash
# Install the vpnon/vpnoff helpers and keep the NordVPN daemon off at boot
# (vpnon starts it on demand). Asks for sudo to change the system units.
# Safe to re-run. Undo: bash install.sh --uninstall
set -e
cd "$(dirname "$(readlink -f "$0")")"

bin=$HOME/.local/bin
# nordvpnd-killswitch.service is static, pulled in only by nordvpnd.service
units="nordvpnd.service nordvpnd.socket"

if [ "${1:-}" = --uninstall ]; then
    rm -f "$bin/vpnon" "$bin/vpnoff"
    sudo systemctl enable $units
    echo "Uninstalled: helpers removed, daemon starts at boot again"
    exit 0
fi

command -v nordvpn >/dev/null || { echo "Missing: nordvpn" >&2; exit 1; }

chmod +x vpnon vpnoff
mkdir -p "$bin"
ln -sfn "$PWD/vpnon" "$bin/vpnon"
ln -sfn "$PWD/vpnoff" "$bin/vpnoff"
# Disable only: a running daemon keeps running until vpnoff or reboot
sudo systemctl disable $units
echo "Done: vpnon/vpnoff installed, NordVPN daemon no longer starts at boot"
