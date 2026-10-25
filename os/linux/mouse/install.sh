#!/usr/bin/bash
# Let browser mouse configurators (WebHID) read and write Logitech mice:
# installs a udev rule giving the logged-in user access to their hidraw nodes.
# Needs sudo. Safe to re-run. Reload the configurator page afterwards.
# Undo: bash install.sh --uninstall
set -e
cd "$(dirname "$(readlink -f "$0")")"

rule=/etc/udev/rules.d/70-logitech-hidraw.rules

if [ "${1:-}" = --uninstall ]; then
    sudo rm -f "$rule"
else
    sudo install -m 644 70-logitech-hidraw.rules "$rule"
fi
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=hidraw --action=change
echo "Done; reload the configurator page"
