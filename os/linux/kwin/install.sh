#!/usr/bin/bash
# Install the Yakuake KWin pieces: the slide-from-the-left effect (docked on
# the left, full height) and the script that keeps it off fullscreen monitors
# and owns its shortcuts (Meta+/, Meta+N new tab), plus yakuake-tab, which new
# tabs run (Claude Code, or a plain shell for Meta+Shift+N). User-level, no sudo. Safe to re-run.
# Undo: bash install.sh --uninstall
# Yakuake reads its window settings on start: restart it after installing.
set -e
cd "$(dirname "$(readlink -f "$0")")"

data=${XDG_DATA_HOME:-$HOME/.local/share}/kwin
yakuake_shortcut="['yakuake', 'toggle-window-state', 'Yakuake', 'Open/Retract Yakuake']"
bin=$HOME/.local/bin/yakuake-tab
apps=${XDG_DATA_HOME:-$HOME/.local/share}/applications
shell_tab="['yakuake-shell-tab.desktop', '_launch', 'New Yakuake shell tab', 'Launch']"

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
    kga unregister yakuake-shell-tab.desktop _launch || true
    rm -f "$apps/yakuake-shell-tab.desktop"
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

# New tabs run yakuake-tab; Meta+Shift+N opens one with a plain shell.
# Absolute path: the Plasma session's PATH may not include ~/.local/bin
mkdir -p "$(dirname "$bin")" "$apps"
ln -sfn "$PWD/yakuake-tab" "$bin"
cat > "$apps/yakuake-shell-tab.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=New Yakuake shell tab
Exec=$bin --shell
Icon=utilities-terminal
NoDisplay=true
X-KDE-GlobalAccel-CommandShortcut=true
EOF
# kglobalaccel drops shortcuts of launchers missing from the sycoca cache
kbuildsycoca6 >/dev/null 2>&1
kga doRegister "$shell_tab"
kga setShortcutKeys "$shell_tab" "[([$((0x1200004E)), 0, 0, 0],)]" 6

# Docked left, full height, 30% wide (the effect slides it in from the left);
# the right edge is the Leaves side panel's
kwriteconfig6 --file yakuakerc --group Window --key Width 30
kwriteconfig6 --file yakuakerc --group Window --key Height 100
kwriteconfig6 --file yakuakerc --group Window --key Position 0
echo "Done; restart Yakuake to dock it on the left"
