#!/usr/bin/bash
# Holding a key repeats it, like other OSs, instead of Plasma's accent menu
# (System Settings > Keyboard > "When a key is held"). User-level, no sudo.
# Safe to re-run. Undo: bash install.sh --uninstall
set -e

key() {  # value; --notify makes KWin pick it up without a relogin
    kwriteconfig6 --notify --file kcminputrc --group Keyboard --key KeyRepeat "$1"
}

if [ "${1:-}" = --uninstall ]; then
    key accent
    echo "Uninstalled; holding a key shows the accent menu again"
    exit 0
fi

key repeat
echo "Done; holding a key now repeats it"
