#!/usr/bin/bash
# Mouse configuration (see README.md):
# - Piper (libratbag) for the G203, whose settings live in its onboard profile
# - Solaar for the MX Master 3, whose button remaps need it running (autostarts)
# - a udev rule so browser configurators (WebHID) can reach Logitech mice
# Needs sudo. Safe to re-run.
# Undo: bash install.sh --uninstall
set -e
cd "$(dirname "$(readlink -f "$0")")"

rule=/etc/udev/rules.d/70-logitech-hidraw.rules

if [ "${1:-}" = --uninstall ]; then
    sudo rm -f "$rule"
    sudo dnf remove -y piper solaar
else
    sudo install -m 644 70-logitech-hidraw.rules "$rule"
    sudo dnf install -y piper solaar
fi
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=hidraw --action=change
[ "${1:-}" = --uninstall ] && exit 0

# Browser configurators (OpenMouse) turn the onboard profile off and keep the
# settings in RAM, which resets at power-off. Turn it back on for Piper.
for dev in $(ratbagctl list 2>/dev/null | grep -i 'G203' | cut -d: -f1); do
    if ratbagctl "$dev" info | grep -q '^Profile 0: (disabled)'; then
        ratbagctl "$dev" profile 0 enable
        echo "Enabled the G203's onboard profile"
    fi
done
echo "Done; set the G203 up in Piper, the MX Master 3 in Solaar"
