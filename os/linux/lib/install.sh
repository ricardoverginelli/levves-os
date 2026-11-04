# What the user-level install.sh scripts share (bash). Source it right after the script's
# `cd` into its own folder, so `link` finds the files next to it:
#   cd "$(dirname "$(readlink -f "$0")")"
#   . ../lib/install.sh              # from os/linux/<thing>; apps use ../../os/linux/lib/install.sh

config=${XDG_CONFIG_HOME:-$HOME/.config}
data=${XDG_DATA_HOME:-$HOME/.local/share}
units=$config/systemd/user
apps=$data/applications
local_bin=$HOME/.local/bin

need() {  # <command>…: stop when one is missing
    for cmd; do
        command -v "$cmd" >/dev/null || { echo "Missing: $cmd" >&2; exit 1; }
    done
}

need_python() {  # <modules, comma-separated> <dnf package>…
    python3 -c "import $1" 2>/dev/null || { shift; echo "Missing packages: sudo dnf install $*" >&2; exit 1; }
}

link() {  # <file in this folder> <destination>
    mkdir -p "$(dirname "$2")"
    ln -sfn "$PWD/$1" "$2"
}

link_units() {  # <unit file in this folder>…: into the user's systemd folder, then reloaded
    for unit; do link "$unit" "$units/$unit"; done
    systemctl --user daemon-reload
}

unlink_units() {  # <unit>…: stopped, disabled and removed
    systemctl --user disable --now "$@" 2>/dev/null || true
    for unit; do rm -f "$units/$unit"; done
    systemctl --user daemon-reload
}

kga() {  # <KGlobalAccel method> <argument>…
    gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel."$@" >/dev/null
}

# Global keys that run a command: a hidden launcher (<id>.desktop) that kglobalaccel binds.
# Keys are Qt key codes as a(ai), e.g. "[([$((0x1200004D)), 0, 0, 0],)]" for Meta+Shift+M
# (Meta 0x10000000, Shift 0x02000000, Ctrl 0x04000000, Alt 0x08000000).
launcher_shortcut() {  # <id> <name> <command> <icon> <keys>
    local shortcut="['$1.desktop', '_launch', '$2', 'Launch']"
    mkdir -p "$apps"
    # An absolute command: the Plasma session's PATH may not include ~/.local/bin.
    # No startup notification: its busy cursor has nothing to wait for
    cat > "$apps/$1.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$2
Exec=$3
Icon=$4
NoDisplay=true
StartupNotify=false
X-KDE-GlobalAccel-CommandShortcut=true
EOF
    # kglobalaccel drops shortcuts of launchers missing from the sycoca cache
    kbuildsycoca6 >/dev/null 2>&1 || true
    kga doRegister "$shortcut"
    kga setForeignShortcutKeys "$shortcut" "$5"
    # Foreign keys alone wait for the next login; SetPresent (2) | NoAutoloading (4) activate them now
    kga setShortcutKeys "$shortcut" "$5" 6
}

remove_launcher_shortcut() {  # <id>
    kga setForeignShortcutKeys "['$1.desktop', '_launch', '', '']" '@a(ai) []' || true
    kga unregister "$1.desktop" _launch || true
    rm -f "$apps/$1.desktop"
    kbuildsycoca6 >/dev/null 2>&1 || true
}
