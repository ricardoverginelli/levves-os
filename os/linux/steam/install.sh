#!/usr/bin/bash
# Show Steam as Steam in the task manager. Its window (class steam, name
# steamwebhelper) names no .desktop file, so Plasma matches it by command line,
# and Steam's game shortcuts (Exec=steam steam://rungameid/…) match before
# steam.desktop (Exec=/usr/bin/steam %U): Steam showed as one of its games.
# A KWin window rule gives the window steam.desktop. User-level, no sudo.
# Safe to re-run. Reopen Steam's window afterwards.
# Undo: bash install.sh --uninstall
set -e

id=steam-desktop-file
rules=$(kreadconfig6 --file kwinrulesrc --group General --key rules)
rules=$(tr , '\n' <<<"$rules" | grep -vx -e "$id" -e '' | paste -sd,) || true

if [ "${1:-}" = --uninstall ]; then
    kwriteconfig6 --file kwinrulesrc --group $id --delete-group
else
    kwriteconfig6 --file kwinrulesrc --group $id --key Description "Steam's window is Steam"
    kwriteconfig6 --file kwinrulesrc --group $id --key wmclass steam
    kwriteconfig6 --file kwinrulesrc --group $id --key wmclassmatch 1 # exact
    kwriteconfig6 --file kwinrulesrc --group $id --key desktopfile steam
    kwriteconfig6 --file kwinrulesrc --group $id --key desktopfilerule 2 # force
    rules=${rules:+$rules,}$id
fi
kwriteconfig6 --file kwinrulesrc --group General --key rules "$rules"
kwriteconfig6 --file kwinrulesrc --group General --key count \
    "$(tr , '\n' <<<"$rules" | grep -c .)"
qdbus-qt6 org.kde.KWin /KWin reconfigure
echo "Done; close and reopen Steam's window"
