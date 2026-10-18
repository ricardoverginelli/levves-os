#!/bin/sh
# Apply the Plasma setup from this folder. Safe to re-run.
set -e
cd "$(dirname "$0")"

echo "Building Plasma style"
python3 -I plasma-style/build.py
plasma-apply-desktoptheme leaves >/dev/null

# plasmashell keeps a widget's old QML loaded until restarted
restart=false
for widget in widgets/*/; do
    id=$(basename "$widget")
    installed="$HOME/.local/share/plasma/plasmoids/$id"
    if [ -d "$installed" ] && diff -rq "$widget" "$installed" >/dev/null; then
        continue
    fi
    echo "Installing widget $id"
    if [ -d "$installed" ]; then
        kpackagetool6 --type Plasma/Applet --upgrade "$widget" >/dev/null
        restart=true
    else
        kpackagetool6 --type Plasma/Applet --install "$widget" >/dev/null
    fi
done

for script in panels/*.js; do
    echo "Applying $script"
    qdbus-qt6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$script")"
done

if [ "$restart" = true ]; then
    echo "Restarting plasmashell to load updated widgets"
    systemctl --user restart plasma-plasmashell
fi
