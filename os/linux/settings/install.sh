#!/usr/bin/bash
# Plasma behavior settings for every machine (see README.md). Only kwriteconfig6, no sudo.
# Safe to re-run. Undo: bash install.sh --uninstall (back to Plasma's defaults)
set -e
cd "$(dirname "$(readlink -f "$0")")"
. ../lib/install.sh

need kwriteconfig6 dbus-send

undo=false
[ "${1:-}" = --uninstall ] && undo=true
set_key() {  # <value> <kwriteconfig6 args…>: the value, or the default when undoing
    local value=$1; shift
    if $undo; then kwriteconfig6 "$@" --delete; else kwriteconfig6 "$@" "$value"; fi
}

# Keyboard: holding a key repeats it, like other OSs, instead of Plasma's accent menu
# (System Settings > Keyboard > "When a key is held"). Also turns off the plasma-keyboard
# input method behind that menu: every keystroke goes through it, and typing fast drops
# dead-key accents ("só" comes out as "so"). No on-screen keyboard afterwards, so not for
# touchscreens. KWin reads these at login.
set_key repeat --notify --file kcminputrc --group Keyboard --key KeyRepeat
# Empty, not deleted: a missing key means KWin's default, plasma-keyboard
set_key "" --file kwinrc --group Wayland --key InputMethod

# Idle: lock after 5 minutes, plugged in or not (Plasma's default). On AC the screen never
# dims or turns off, even locked; on battery Plasma's defaults still dim and turn it off
set_key true --file kscreenlockerrc --group Daemon --key Autolock
set_key 5 --file kscreenlockerrc --group Daemon --key Timeout
set_key false --file powerdevilrc --group AC --group Display --key DimDisplayWhenIdle
set_key false --file powerdevilrc --group AC --group Display --key TurnOffDisplayWhenIdle
# Both daemons reread their files when told to
dbus-send --session --dest=org.freedesktop.ScreenSaver --type=method_call \
    /ScreenSaver org.kde.screensaver.configure
dbus-send --session --dest=org.kde.Solid.PowerManagement --type=method_call \
    /org/kde/Solid/PowerManagement org.kde.Solid.PowerManagement.reparseConfiguration

# Notifications: popups close after 3.3 s, a third less than Plasma's 5 s
set_key 3333 --file plasmanotifyrc --group Notifications --key PopupTimeout

# Calendar reminders come from the Leaves clock widget (30, 10, 5 and 1 minute before).
# Akonadi's own reminder daemon is off: at login it replayed every alarm missed since the last one
set_key false --file kalendaracrc --group General --key Autostart
$undo || pkill -x kalendarac || true

echo "Done; log out and back in for the keyboard settings"
