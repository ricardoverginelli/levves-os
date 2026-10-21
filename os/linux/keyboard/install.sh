#!/usr/bin/bash
# Holding a key repeats it, like other OSs, instead of Plasma's accent menu
# (System Settings > Keyboard > "When a key is held"). Also turns off the
# plasma-keyboard input method behind that menu: every keystroke goes through
# it, and typing fast drops dead-key accents ("só" comes out as "so").
# No on-screen keyboard afterwards, so not for touchscreens. User-level, no sudo.
# Safe to re-run. KWin reads these at login: log out and back in.
# Undo: bash install.sh --uninstall
set -e

if [ "${1:-}" = --uninstall ]; then
    kwriteconfig6 --notify --file kcminputrc --group Keyboard --key KeyRepeat accent
    kwriteconfig6 --file kwinrc --group Wayland --key InputMethod --delete
    echo "Uninstalled; log out and back in for the accent menu"
    exit 0
fi

kwriteconfig6 --notify --file kcminputrc --group Keyboard --key KeyRepeat repeat
# Empty, not deleted: a missing key means KWin's default, plasma-keyboard
kwriteconfig6 --file kwinrc --group Wayland --key InputMethod ""
echo "Done; log out and back in to apply"
