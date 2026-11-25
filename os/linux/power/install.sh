#!/usr/bin/bash
# Lock and screen idle settings (see README.md). User-level, no sudo. Safe to re-run.
# Undo: bash install.sh --uninstall (back to Plasma's defaults)
set -e
cd "$(dirname "$(readlink -f "$0")")"
. ../lib/install.sh

need kwriteconfig6 dbus-send

lock="--file kscreenlockerrc --group Daemon"
display="--file powerdevilrc --group AC --group Display"

if [ "${1:-}" = --uninstall ]; then
    for key in Autolock Timeout; do kwriteconfig6 $lock --key $key --delete; done
    for key in DimDisplayWhenIdle TurnOffDisplayWhenIdle; do
        kwriteconfig6 $display --key $key --delete
    done
else
    # Lock after 5 idle minutes, plugged in or not (Plasma's default)
    kwriteconfig6 $lock --key Autolock true
    kwriteconfig6 $lock --key Timeout 5
    # On AC the screen stays on, even locked; on battery Plasma's defaults dim and turn it off
    kwriteconfig6 $display --key DimDisplayWhenIdle false
    kwriteconfig6 $display --key TurnOffDisplayWhenIdle false
fi

# Both daemons reread their files when told to
dbus-send --session --dest=org.freedesktop.ScreenSaver --type=method_call \
    /ScreenSaver org.kde.screensaver.configure
dbus-send --session --dest=org.kde.Solid.PowerManagement --type=method_call \
    /org/kde/Solid/PowerManagement org.kde.Solid.PowerManagement.reparseConfiguration
echo "Done"
