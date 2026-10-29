#!/usr/bin/bash
# Install Meta+Alt+N: a new Yakuake tab with Claude Code on the business login
# (~/.claude-gorila). Laptop only, where that login lives. Needs kwin/install.sh
# (yakuake-tab and the "New Yakuake Tab" shortcut). User-level, no sudo. Safe to re-run.
# Undo: bash install.sh --uninstall
set -e
cd "$(dirname "$(readlink -f "$0")")"

bin=$HOME/.local/bin/yakuake-business-tab
app=${XDG_DATA_HOME:-$HOME/.local/share}/applications/yakuake-business-tab.desktop
id="['yakuake-business-tab.desktop', '_launch', 'New Yakuake business Claude tab', 'Launch']"

kga() {
    gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel."$@" >/dev/null
}

if [ "${1:-}" = --uninstall ]; then
    kga unregister yakuake-business-tab.desktop _launch || true
    rm -f "$bin" "$app"
    echo "Uninstalled"
    exit 0
fi

[ -d ~/.claude-gorila ] || { echo "No business login here (~/.claude-gorila)" >&2; exit 1; }
[ -x ~/.local/bin/yakuake-tab ] || { echo "Run kwin/install.sh first" >&2; exit 1; }

# Absolute path: the Plasma session's PATH may not include ~/.local/bin
mkdir -p "$(dirname "$bin")" "$(dirname "$app")"
ln -sfn "$PWD/yakuake-business-tab" "$bin"
cat > "$app" <<EOF
[Desktop Entry]
Type=Application
Name=New Yakuake business Claude tab
Exec=$bin
Icon=utilities-terminal
NoDisplay=true
X-KDE-GlobalAccel-CommandShortcut=true
EOF
# kglobalaccel drops shortcuts of launchers missing from the sycoca cache
kbuildsycoca6 >/dev/null 2>&1
kga doRegister "$id"
kga setShortcutKeys "$id" "[([$((0x1800004E)), 0, 0, 0],)]" 6  # Meta+Alt+N
echo "Done. Meta+Alt+N opens a Yakuake tab with Claude Code on the business login."
