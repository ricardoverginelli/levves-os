#!/usr/bin/bash
# Install the Yakuake KWin pieces: the slide-from-the-left effect (docked on
# the left, full height) and the script that keeps it off fullscreen monitors
# and owns its shortcuts (Meta+/, Meta+N new tab, Meta+F full screen), plus
# yakuake-tab, which new tabs run (Claude Code, or a plain shell for
# Meta+Shift+N), and yakuake-panes (Shift+Left/Right through split terminals,
# then tabs). User-level, no sudo. Safe to re-run.
# Undo: bash install.sh --uninstall
# Yakuake reads its window settings on start: restart it when this says so.
set -e
cd "$(dirname "$(readlink -f "$0")")"
. ../lib/install.sh

kwin=$data/kwin
yakuake_shortcut="['yakuake', 'toggle-window-state', 'Yakuake', 'Open/Retract Yakuake']"
bin=$local_bin/yakuake-tab

plugin() {  # id, enabled
    kwriteconfig6 --file kwinrc --group Plugins --key "${1}Enabled" "$2"
}
# Yakuake only reads yakuakerc on start, so note when a value actually changes
yakuake_changed=false
yakuake_set() {  # group, key, value
    [ "$(kreadconfig6 --file yakuakerc --group "$1" --key "$2")" = "$3" ] && return
    kwriteconfig6 --file yakuakerc --group "$1" --key "$2" "$3"
    yakuake_changed=true
}

if [ "${1:-}" = --uninstall ]; then
    plugin yakuake-slide false
    plugin yakuake-avoid-fullscreen false
    plugin yakuake-panes false
    plugin slidingpopups true
    qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript yakuake-avoid-fullscreen >/dev/null || true
    qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript yakuake-panes >/dev/null || true
    qdbus-qt6 org.kde.KWin /KWin reconfigure
    rm -rf "$kwin/effects/yakuake-slide" "$kwin/scripts/yakuake-avoid-fullscreen" "$kwin/scripts/yakuake-panes"
    # Yakuake's own tab and terminal keys back
    for action in previous-session next-session previous-terminal next-terminal; do
        kwriteconfig6 --file yakuakerc --group Shortcuts --key $action --delete
    done
    remove_launcher_shortcut yakuake-shell-tab
    # $bin stays: Yakuake's profile runs it (plasma/yakuake/build.py)
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
rm -rf "$kwin/effects/yakuake-slide"
mkdir -p "$kwin/effects"
cp -r yakuake-slide "$kwin/effects/"
plugin slidingpopups false
plugin yakuake-slide true

echo "Installing KWin script yakuake-avoid-fullscreen"
rm -rf "$kwin/scripts/yakuake-avoid-fullscreen"
mkdir -p "$kwin/scripts"
cp -r yakuake-avoid-fullscreen "$kwin/scripts/"
plugin yakuake-avoid-fullscreen true
qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript yakuake-avoid-fullscreen >/dev/null || true

echo "Installing KWin script yakuake-panes"
rm -rf "$kwin/scripts/yakuake-panes"
cp -r yakuake-panes "$kwin/scripts/"
plugin yakuake-panes true
qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript yakuake-panes >/dev/null || true

qdbus-qt6 org.kde.KWin /KWin reconfigure
# Reload the effect so a re-run picks up changed code (reconfigure doesn't)
qdbus-qt6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect yakuake-slide >/dev/null || true
qdbus-qt6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect yakuake-slide >/dev/null

# The script registers Meta+/; Yakuake's own shortcut must not take the key
kga setForeignShortcutKeys "$yakuake_shortcut" '@a(ai) []'

# New tabs run yakuake-tab; Meta+Shift+N opens one with a plain shell
link yakuake-tab "$bin"
launcher_shortcut yakuake-shell-tab "New Yakuake shell tab" "$bin --shell" utilities-terminal \
    "[([$((0x1200004E)), 0, 0, 0],)]"

# Docked left, full height, 30% wide (the effect slides it in from the left);
# the right edge is the Leaves side panel's
yakuake_set Window Width 30
yakuake_set Window Height 100
yakuake_set Window Position 0
# Shift+Left/Right step through a tab's split terminals (yakuake-panes takes
# the key at the first/last one to switch tabs), so the tab keys give them up
yakuake_set Shortcuts previous-terminal "Shift+Left; Ctrl+Shift+Tab"
yakuake_set Shortcuts next-terminal "Shift+Right; Ctrl+Tab"
yakuake_set Shortcuts previous-session none
yakuake_set Shortcuts next-session none
if [ "$yakuake_changed" = true ]; then
    echo "Done; restart Yakuake to dock it on the left and pick up its keys"
fi
