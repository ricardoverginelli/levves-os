#!/usr/bin/bash
# Piper for the Logitech G203 LIGHTSYNC (see README.md). Desktop only.
# Needs sudo. Safe to re-run.
# Undo: bash install.sh --uninstall
set -e

if [ "${1:-}" = --uninstall ]; then
    sudo dnf remove -y piper
    exit 0
fi

lsusb -d 046d:c092 >/dev/null || { echo "No G203 LIGHTSYNC (046d:c092) plugged in" >&2; exit 1; }
sudo dnf install -y piper

# Browser configurators (OpenMouse) turn the onboard profile off and keep the
# settings in RAM, which resets at power-off. Turn it back on for Piper.
for dev in $(ratbagctl list | grep -i 'G203' | cut -d: -f1); do
    if ratbagctl "$dev" info | grep -q '^Profile 0: (disabled)'; then
        ratbagctl "$dev" profile 0 enable
        echo "Enabled the G203's onboard profile"
    fi
done
echo "Done; set the G203 up in Piper"
