#!/bin/sh
# Apply the Plasma setup from this folder. Safe to re-run.
set -e
cd "$(dirname "$0")"

# plasmashell keeps a widget's old QML and the style's cached SVGs until restarted
restart=false

style="$HOME/.local/share/plasma/desktoptheme/leaves"
style_hash() { [ -d "$style" ] && find "$style" -type f -exec sha1sum {} + | sort | sha1sum; }
before=$(style_hash || true)
echo "Building Plasma style"
python3 -I plasma-style/build.py
plasma-apply-desktoptheme leaves >/dev/null
if [ "$before" != "$(style_hash)" ]; then
    # Plasma caches rendered SVGs and their element sizes; stale ones keep the old shapes
    rm -f "$HOME/.cache/plasma_theme_leaves.kcache" "$HOME/.cache/ksvg-elements"
    restart=true
fi

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

# Icons (DESIGN.md): MingCute and our own drawings, installed by name
# (mingcute-<name>, leaves-<name>) so any widget can use them
[ "$(python3 -I icons/install.py)" = changed ] && restart=true

# Shared QML helpers for the widgets (e.g. the message bus), then the Leaves
# tray, which needs them; top-bar.js below picks the tray up
mkdir -p "$HOME/.local/share/leaves"
for file in shared/*.js shared/*.qml; do
    if ! cmp -s "$file" "$HOME/.local/share/leaves/$(basename "$file")"; then
        cp "$file" "$HOME/.local/share/leaves/"
        restart=true
    fi
done
echo "Building the Leaves tray"
[ "$(python3 -I tray/build.py)" = changed ] && restart=true
# Notification popups and history; top-bar.js swaps them in for the stock ones
echo "Building the Leaves notifications"
[ "$(python3 -I notifications/build.py)" = changed ] && restart=true

# Yakuake (and its Konsole profile): Leaves color scheme, font and skin.
# Yakuake only reloads them on restart, which would end its sessions, so just say so
if [ "$(python3 -I yakuake/build.py)" = changed ]; then
    echo "Yakuake theme updated; restart Yakuake to see it"
fi

# VS Code: Leaves color theme, installed as a local extension
if command -v code >/dev/null && [ "$(python3 -I vscode/build.py)" = changed ]; then
    echo "VS Code theme updated; pick Leaves (or Developer: Reload Window) to see it"
fi

# Wallpaper: desktop and lock screen use a copy in our data folder
wallpaper="$HOME/.local/share/wallpapers/leaves.png"
if ! cmp -s wallpaper/leaves.png "$wallpaper"; then
    echo "Installing the wallpaper"
    mkdir -p "$(dirname "$wallpaper")"
    cp wallpaper/leaves.png "$wallpaper"
fi
if ! grep -qx "Image=file://$wallpaper" "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"; then
    plasma-apply-wallpaperimage "$wallpaper" >/dev/null
fi
lock="--file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General"
kwriteconfig6 $lock --key Image "file://$wallpaper"
kwriteconfig6 $lock --key PreviewImage "file://$wallpaper"

# Login screen: same wallpaper and Plasma style plus our Plasma settings (colors,
# theme, cursor, keyboard, monitors). Needs root, so it only asks when any of that changed
config=${XDG_CONFIG_HOME:-$HOME/.config}
stamp="$HOME/.local/state/leaves/login-screen"
login_hash=$({
    cat "$wallpaper" login-screen/install.sh
    find "$style" -type f -exec cat {} +
    for file in kdeglobals plasmarc plasma-localerc kcminputrc kxkbrc \
                kwinoutputconfig.json fontconfig/fonts.conf; do
        cat "$config/$file" 2>/dev/null || true
    done
} | sha1sum)
if [ "$(cat "$stamp" 2>/dev/null)" != "$login_hash" ]; then
    echo "Updating the login screen (asks for your password)"
    if pkexec sh "$PWD/login-screen/install.sh" "$wallpaper" "$config" "$style"; then
        mkdir -p "$(dirname "$stamp")"
        echo "$login_hash" > "$stamp"
    else
        echo "Login screen not updated; it will ask again on the next run"
    fi
fi

# File search (launcher, KRunner): Fedora only indexes Documents, Pictures,
# Videos and Music by default
for folder in Downloads Desktop; do
    balooctl6 config add includeFolders "$HOME/$folder" >/dev/null 2>&1 || true
done

for script in panels/*.js; do
    echo "Applying $script"
    qdbus-qt6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$script")"
done

# KWin shortcuts: halves only, no quarters. Meta+Up/Down move a window between
# the stacked monitors, Meta+Shift+Up maximizes, Meta+Shift+Down minimizes, and
# Meta+Shift+Left/Right are freed for the snap assist script. Keys are Qt key
# codes: Meta 0x10000000, Shift 0x02000000, Up 0x01000013, Down 0x01000015,
# PgUp 0x01000016, PgDown 0x01000017. Everything is cleared first, so a key
# moving from one action to another never conflicts.
kwin_shortcut() {  # action, friendly name, keys as a(ai)
    gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel.setForeignShortcutKeys "['kwin', '$1', 'KWin', '$2']" "$3" >/dev/null
}
none='@a(ai) []'
kwin_shortcut "Window Quick Tile Top" "Quick Tile Window to the Top" "$none"
kwin_shortcut "Window Quick Tile Bottom" "Quick Tile Window to the Bottom" "$none"
kwin_shortcut "Window to Next Screen" "Move Window to Next Screen" "$none"
kwin_shortcut "Window to Previous Screen" "Move Window to Previous Screen" "$none"
kwin_shortcut "Window Maximize" "Maximize Window" "$none"
kwin_shortcut "Window Minimize" "Minimize Window" "$none"
kwin_shortcut "Window One Screen Up" "Move Window One Screen Up" "$none"
kwin_shortcut "Window One Screen Down" "Move Window One Screen Down" "$none"
kwin_shortcut "Window One Screen Up" "Move Window One Screen Up" "[([$((0x11000013)), 0, 0, 0],)]"
kwin_shortcut "Window One Screen Down" "Move Window One Screen Down" "[([$((0x11000015)), 0, 0, 0],)]"
kwin_shortcut "Window Maximize" "Maximize Window" "[([$((0x13000013)), 0, 0, 0],), ([$((0x11000016)), 0, 0, 0],)]"
kwin_shortcut "Window Minimize" "Minimize Window" "[([$((0x13000015)), 0, 0, 0],), ([$((0x11000017)), 0, 0, 0],)]"

# KWin scripts: copy the package, render main.js from its template, enable, reload
for script in kwin/*/; do
    id=$(basename "$script")
    dest="$HOME/.local/share/kwin/scripts/$id"
    echo "Installing KWin script $id"
    rm -rf "$dest"
    mkdir -p "$dest"
    cp -r "$script"/. "$dest"
    template="$dest/contents/code/main.template.js"
    if [ -f "$template" ]; then
        python3 -I - "$template" panels/top-bar.js "$dest/contents/code/main.js" <<'PY'
import json, sys
template, bar, out = sys.argv[1:]
code = open(template).read().replace("/*BAR_SCRIPT*/", json.dumps(open(bar).read()))
open(out, "w").write(code)
PY
        rm "$template"
    fi
    kwriteconfig6 --file kwinrc --group Plugins --key "${id}Enabled" true
    qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$id" >/dev/null
done
qdbus-qt6 org.kde.KWin /KWin reconfigure

# KWin effects: copy the package, enable it, reload it (reconfigure keeps the old code)
for effect in kwin-effects/*/; do
    id=$(basename "$effect")
    dest="$HOME/.local/share/kwin/effects/$id"
    echo "Installing KWin effect $id"
    rm -rf "$dest"
    mkdir -p "$dest"
    cp -r "$effect"/. "$dest"
    kwriteconfig6 --file kwinrc --group Plugins --key "${id}Enabled" true
    qdbus-qt6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect "$id" >/dev/null || true
    qdbus-qt6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect "$id" >/dev/null
done

# Yakuake's KWin effect and script (right-side slide, fullscreen avoidance)
bash ../kwin/install.sh

if [ "$restart" = true ]; then
    echo "Restarting plasmashell to load the updated style/widgets"
    systemctl --user restart plasma-plasmashell
fi
