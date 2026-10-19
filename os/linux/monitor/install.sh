#!/usr/bin/bash
# Install the main-monitor toggle hotkey (see README.md). User-level, no sudo.
# Safe to re-run. Undo: bash install.sh --uninstall
set -e
cd "$(dirname "$(readlink -f "$0")")"

bin=$HOME/.local/bin/main-monitor
apps=${XDG_DATA_HOME:-$HOME/.local/share}/applications
id=main-monitor-toggle.desktop
name="Toggle main monitor"
# Qt key codes: Meta 0x10000000 | Shift 0x02000000 | M 0x4D
keys="[([$((0x1200004D)), 0, 0, 0],)]"

kga() {
    gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel."$@" >/dev/null
}

if [ "${1:-}" = --uninstall ]; then
    kga setForeignShortcutKeys "['$id', '_launch', '$name', 'Launch']" '@a(ai) []' || true
    kga unregister "$id" _launch || true
    rm -f "$apps/$id" "$bin"
    kbuildsycoca6 2>/dev/null || true
    echo "Uninstalled"
    exit 0
fi

for cmd in kscreen-doctor jq; do
    command -v $cmd >/dev/null || { echo "Missing: $cmd" >&2; exit 1; }
done

chmod +x main-monitor
mkdir -p "$(dirname "$bin")" "$apps"
ln -sfn "$PWD/main-monitor" "$bin"
# Absolute path: the Plasma session's PATH may not include ~/.local/bin
cat > "$apps/$id" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$bin toggle
Icon=video-display
NoDisplay=true
X-KDE-GlobalAccel-CommandShortcut=true
DESKTOP
kga doRegister "['$id', '_launch', '$name', 'Launch']"
kga setForeignShortcutKeys "['$id', '_launch', '$name', 'Launch']" "$keys"
# Foreign keys alone leave the shortcut inactive until the next login;
# flags SetPresent (2) | NoAutoloading (4) activate it now
kga setShortcutKeys "['$id', '_launch', '$name', 'Launch']" "$keys" 6
kbuildsycoca6 2>/dev/null || true
echo "Done: Meta+Shift+M toggles the main monitor"
