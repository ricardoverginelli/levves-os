#!/usr/bin/bash
# Middle click like on Windows (see README.md): no paste of selected text, and
# autoscroll in Chrome and Brave. User-level, no sudo. Safe to re-run.
# Log out and back in afterwards.
# Undo: bash install.sh --uninstall
set -e
cd "$(dirname "$(readlink -f "$0")")"

browsers="google-chrome brave-browser"
bin=~/.local/bin
apps=~/.local/share/applications

if [ "${1:-}" = --uninstall ]; then
    kwriteconfig6 --file kwinrc --group Wayland --key EnablePrimarySelection --delete
    for b in $browsers; do
        rm -f "$bin/$b-stable"
        grep -qs MiddleClickAutoscroll "$apps/$b.desktop" && rm -f "$apps/$b.desktop"
    done
    echo "Uninstalled; log out and back in to apply"
    exit 0
fi

# System Settings > General Behavior > "Middle Click: Paste selected text"
kwriteconfig6 --file kwinrc --group Wayland --key EnablePrimarySelection false

mkdir -p "$bin" "$apps"
for b in $browsers; do
    [ -x "/usr/bin/$b-stable" ] || continue
    ln -sf "$PWD/browser-autoscroll" "$bin/$b-stable"
    # Menu and taskbar launchers use the full /usr/bin path, so point them at
    # the wrapper. A copy: re-run after an update changes the system one.
    sed "s|^Exec=/usr/bin/|Exec=$bin/|; 1a # Made by levves mouse/middle-click (MiddleClickAutoscroll)" \
        "/usr/share/applications/$b.desktop" > "$apps/$b.desktop"
done
echo "Done; log out and back in, and fully quit Chrome and Brave first"
