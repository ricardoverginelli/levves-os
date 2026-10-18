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

# Icons (DESIGN.md): MingCute SVGs go into the user's hicolor theme as
# mingcute-<name> and our own drawings as leaves-<name>, so any widget can use
# them by name. Plasma caches icon lookups, so a change means a restart.
icons="$HOME/.local/share/icons/hicolor/scalable/actions"
mkdir -p "$icons"
for svg in icons/mingcute/*.svg icons/custom/*.svg; do
    case "$svg" in icons/custom/*) prefix=leaves ;; *) prefix=mingcute ;; esac
    dest="$icons/$prefix-$(basename "$svg")"
    cmp -s "$svg" "$dest" && continue
    cp "$svg" "$dest"
    rm -f "$HOME/.cache/icon-cache.kcache"
    restart=true
done

# File search (launcher, KRunner): Fedora only indexes Documents, Pictures,
# Videos and Music by default
for folder in Downloads Desktop; do
    balooctl6 config add includeFolders "$HOME/$folder" >/dev/null 2>&1 || true
done

for script in panels/*.js; do
    echo "Applying $script"
    qdbus-qt6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$script")"
done

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

if [ "$restart" = true ]; then
    echo "Restarting plasmashell to load the updated style/widgets"
    systemctl --user restart plasma-plasmashell
fi
