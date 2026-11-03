#!/usr/bin/bash
# Install the ShareX-style capture hotkeys (see README.md). User-level, no sudo;
# the packages are: sudo dnf copr enable brycensranch/gpu-screen-recorder-git &&
#   sudo dnf install gpu-screen-recorder slurp ffmpeg python3-pyqt6
# Safe to re-run. Undo: bash install.sh --uninstall
set -e
cd "$(dirname "$(readlink -f "$0")")"

bin=$HOME/.local/bin/capture
apps=${XDG_DATA_HOME:-$HOME/.local/share}/applications
tmpfiles=${XDG_CONFIG_HOME:-$HOME/.config}/user-tmpfiles.d
units=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user

# Qt key codes: Print 0x01000009, F10 0x01000039, F19 0x01000042,
# U 0x55; Shift 0x02000000, Ctrl 0x04000000, Alt 0x08000000. KWin drops Shift
# from Shift+Alt+Print, so keyd (keyd/gmk104.conf) sends Shift+Alt+F19 for those;
# both keys are bound. Ctrl+Alt+F10 switches to VT 10, so keyd sends Ctrl+Alt+F19
# (not F20: xkb maps it to XF86AudioMicMute).
# id | name | args | keys (comma-separated)
hotkeys="\
shot-region-clip|Screenshot region to clipboard|shot region clip|$((0x01000009))
shot-region-upload|Screenshot region and upload|shot region upload|$((0x05000009))
shot-last-clip|Screenshot last region to clipboard|shot last clip|$((0x03000009))
shot-last-upload|Screenshot last region and upload|shot last upload|$((0x07000009))
gif-region-clip|Record GIF of region|gif region clip|$((0x09000009))
gif-region-upload|Record GIF of region and upload|gif region upload|$((0x0B000009)),$((0x0A000042))
gif-last-clip|Record GIF of last region|gif last clip|$((0x0D000009))
mp4-region-clip|Record MP4 of region|mp4 region clip|$((0x0F000009)),$((0x0E000042))
clipboard-upload|Upload clipboard image|clipboard upload|$((0x0E000055))
replay-save|Save instant replay|replay save|$((0x09000039))
replay-toggle|Toggle instant replay buffer|replay toggle|$((0x0B000039))
replay-folder|Open instant replay folder|replay folder|$((0x0D000042))"

shortcut() {  # component, action, component name, action name, keys as a(ai)
    gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel.doRegister "['$1', '$2', '$3', '$4']" >/dev/null
    gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel.setForeignShortcutKeys "['$1', '$2', '$3', '$4']" "$5" >/dev/null
}
none='@a(ai) []'
spectacle=org.kde.spectacle.desktop

if [ "${1:-}" = --uninstall ]; then
    while IFS='|' read -r id name args keys; do
        shortcut "capture-$id.desktop" _launch "$name" "Launch" "$none"
        gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
            --method org.kde.KGlobalAccel.unregister "capture-$id.desktop" _launch >/dev/null || true
        rm -f "$apps/capture-$id.desktop"
    done <<< "$hotkeys"
    systemctl --user disable --now capture-replay.service capture-tray.service 2>/dev/null || true
    rm -f "$bin" "$tmpfiles/capture.conf" "$units/capture-replay.service" "$units/capture-tray.service"
    systemctl --user daemon-reload
    # Spectacle's defaults back: Print launches it, Shift+Print captures the desktop
    shortcut $spectacle _launch Spectacle "Launch Spectacle" "[([$((0x12000053)), 0, 0, 0],), ([$((0x01000009)), 0, 0, 0],)]"
    shortcut $spectacle FullScreenScreenShot Spectacle "Capture Entire Desktop" "[([$((0x03000009)), 0, 0, 0],)]"
    echo "Uninstalled"
    exit 0
fi

for cmd in slurp spectacle gpu-screen-recorder ffmpeg magick wl-copy curl jq kscreen-doctor wayland-info gio; do
    command -v $cmd >/dev/null || { echo "Missing: $cmd" >&2; exit 1; }
done
python3 -c "import PyQt6.QtQml, PyQt6.QtSvg" 2>/dev/null || { echo "Missing package: sudo dnf install python3-pyqt6"; exit 1; }

chmod +x capture replay-tray
mkdir -p "$(dirname "$bin")" "$apps" "$tmpfiles" "$units"
ln -sfn "$PWD/capture" "$bin"
# Daily cleanup of old captures (see tmpfiles.conf)
ln -sfn "$PWD/tmpfiles.conf" "$tmpfiles/capture.conf"

# Spectacle keeps its Meta shortcuts; Print and Shift+Print move to capture
shortcut $spectacle _launch Spectacle "Launch Spectacle" "[([$((0x12000053)), 0, 0, 0],)]"
shortcut $spectacle FullScreenScreenShot Spectacle "Capture Entire Desktop" "$none"

while IFS='|' read -r id name args keys; do
    echo "Hotkey: $name"
    # Absolute path: the Plasma session's PATH may not include ~/.local/bin.
    # No startup notification: its busy cursor would end up in screenshots
    cat > "$apps/capture-$id.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Exec=$bin $args
Icon=spectacle
NoDisplay=true
StartupNotify=false
X-KDE-GlobalAccel-CommandShortcut=true
EOF
done <<< "$hotkeys"
# kglobalaccel drops shortcuts of launchers missing from the sycoca cache
kbuildsycoca6 2>/dev/null || true

while IFS='|' read -r id name args keys; do
    keys="[$(printf '([%s, 0, 0, 0],)\n' ${keys//,/ } | paste -sd,)]"
    shortcut "capture-$id.desktop" _launch "$name" "Launch" "$keys"
    # Foreign keys alone leave the shortcut inactive until the next login;
    # flags SetPresent (2) | NoAutoloading (4) activate it now
    gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel.setShortcutKeys \
        "['capture-$id.desktop', '_launch', '$name', 'Launch']" "$keys" 6 >/dev/null
done <<< "$hotkeys"

# Instant replay buffer, started with every Plasma session (restart to pick up changes)
ln -sfn "$PWD/capture-replay.service" "$units/capture-replay.service"
systemctl --user daemon-reload
systemctl --user enable capture-replay.service
systemctl --user restart capture-replay.service

# Tray icon (amber while the buffer records), which also swaps LosslessCut cuts in
ln -sfn "$PWD/capture-tray.service" "$units/capture-tray.service"
systemctl --user daemon-reload
systemctl --user enable capture-tray.service
systemctl --user restart capture-tray.service

# LosslessCut (Flatpak): no .llc project files; a cut exports as X-cut.mp4 and
# closes the file, then replay-tray trashes X.mp4 and renames the cut to it.
# Its own "trash source" would rm the original for good (the Flatpak's trash is rm)
llc=$HOME/.var/app/no.mifi.losslesscut/config/LosslessCut/config.json
if [ -f "$llc" ]; then
    if flatpak ps --columns=application 2>/dev/null | grep -qx no.mifi.losslesscut; then
        echo "LosslessCut is open (it rewrites its settings on exit): close it and re-run" >&2
    else
        echo "LosslessCut: cuts replace the original"
        # shellcheck disable=SC2016
        jq '.autoSaveProjectFile = false | .enableOverwriteOutput = true
            | .outSegTemplate = "${FILENAME}-cut${SEG_SUFFIX}${EXT}"
            | .cleanupChoices += {cleanupAfterExport: true, askForCleanup: false, closeFile: true,
                trashTmpFiles: true, trashProjectFile: true, trashSourceFile: false}' \
            "$llc" > "$llc.new" && mv "$llc.new" "$llc"
    fi
fi
echo "Done"
