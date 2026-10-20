#!/usr/bin/bash
# Install the Yakuake KWin pieces: the slide-from-the-right effect (docked on
# the right, full height) and the script that keeps it off fullscreen monitors
# and owns its shortcut (Meta+/). User-level, no sudo. Safe to re-run.
# Undo: bash install.sh --uninstall
# Yakuake reads its window settings on start: restart it after installing.
set -e
cd "$(dirname "$(readlink -f "$0")")"

data=${XDG_DATA_HOME:-$HOME/.local/share}/kwin
yakuake_shortcut="['yakuake', 'toggle-window-state', 'Yakuake', 'Open/Retract Yakuake']"

kga() {
    gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel."$@" >/dev/null
}
plugin() {  # id, enabled
    kwriteconfig6 --file kwinrc --group Plugins --key "${1}Enabled" "$2"
}

if [ "${1:-}" = --uninstall ]; then
    plugin yakuake-slide false
    plugin yakuake-avoid-fullscreen false
    plugin slidingpopups true
    qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript yakuake-avoid-fullscreen >/dev/null || true
    qdbus-qt6 org.kde.KWin /KWin reconfigure
    rm -rf "$data/effects/yakuake-slide" "$data/scripts/yakuake-avoid-fullscreen"
    # Yakuake's own F12 back, docked at the top again
    kga setForeignShortcutKeys "$yakuake_shortcut" "[([$((0x0100003B)), 0, 0, 0],)]"
    kwriteconfig6 --file yakuakerc --group Window --key Width 90
    kwriteconfig6 --file yakuakerc --group Window --key Height 50
    kwriteconfig6 --file yakuakerc --group Window --key Position 50
    echo "Uninstalled; restart Yakuake"
    exit 0
fi

# Effect: Sliding popups off, or Yakuake keeps asking it for a top slide
echo "Installing KWin effect yakuake-slide"
rm -rf "$data/effects/yakuake-slide"
mkdir -p "$data/effects"
cp -r yakuake-slide "$data/effects/"
plugin slidingpopups false
plugin yakuake-slide true

echo "Installing KWin script yakuake-avoid-fullscreen"
rm -rf "$data/scripts/yakuake-avoid-fullscreen"
mkdir -p "$data/scripts"
cp -r yakuake-avoid-fullscreen "$data/scripts/"
plugin yakuake-avoid-fullscreen true
qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript yakuake-avoid-fullscreen >/dev/null || true

qdbus-qt6 org.kde.KWin /KWin reconfigure
# Reload the effect so a re-run picks up changed code (reconfigure doesn't)
qdbus-qt6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect yakuake-slide >/dev/null || true
qdbus-qt6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect yakuake-slide >/dev/null

# The script registers Meta+/; Yakuake's own shortcut must not take the key
kga setForeignShortcutKeys "$yakuake_shortcut" '@a(ai) []'

# Docked right, full height, 30% wide (the effect slides it in from the right)
kwriteconfig6 --file yakuakerc --group Window --key Width 30
kwriteconfig6 --file yakuakerc --group Window --key Height 100
kwriteconfig6 --file yakuakerc --group Window --key Position 100
echo "Done; restart Yakuake to dock it on the right"
