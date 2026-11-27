#!/usr/bin/bash
# Install the instant replay buffer, its hotkeys and tray icon (see README.md).
# User-level, no sudo; the packages are: sudo dnf copr enable
#   brycensranch/gpu-screen-recorder-git && sudo dnf install gpu-screen-recorder python3-pyside6
# Safe to re-run. Undo: bash install.sh --uninstall
set -e
cd "$(dirname "$(readlink -f "$0")")"
. ../lib/install.sh

bin=$local_bin/instant-replay
replay_off=$config/capture/replay-off-by-default

# Qt key codes: F10 0x01000039, F19 0x01000042; Shift 0x02000000, Ctrl 0x04000000,
# Alt 0x08000000. Ctrl+Alt+F10 switches to VT 10, so keyd (keyd/gmk104.conf) sends
# Ctrl+Alt+F19 (not F20: xkb maps it to XF86AudioMicMute).
# The ids are capture's from before the split, so existing bindings carry over.
# id | name | args | keys
hotkeys="\
capture-replay-save|Save instant replay|save|$((0x09000039))
capture-replay-toggle|Toggle instant replay buffer|toggle|$((0x0B000039))
capture-replay-folder|Open instant replay folder|folder|$((0x0D000042))"

if [ "${1:-}" = --uninstall ]; then
    while IFS='|' read -r id name args keys; do
        remove_launcher_shortcut "$id"
    done <<<"$hotkeys"
    unlink_units capture-replay.service capture-tray.service
    rm -f "$bin"
    echo "Uninstalled"
    exit 0
fi

need gpu-screen-recorder jq kscreen-doctor notify-send
need_python PySide6.QtSvg python3-pyside6

chmod +x instant-replay replay-tray
link instant-replay "$bin"

while IFS='|' read -r id name args keys; do
    echo "Hotkey: $name"
    launcher_shortcut "$id" "$name" "$bin $args" media-record "[([$keys, 0, 0, 0],)]"
done <<<"$hotkeys"

# Instant replay buffer, started with every Plasma session (restart to pick up changes),
# unless this machine has it off by default (capture-replay-off/ sets $replay_off)
link_units capture-replay.service
if [ -e "$replay_off" ]; then
    echo "Instant replay: off by default here (Alt+Shift+F10 turns it on)"
    systemctl --user disable --now capture-replay.service 2>/dev/null || true
    link_units capture-replay.service # disabling a linked unit removes its link too
else
    systemctl --user enable capture-replay.service
    systemctl --user restart capture-replay.service
fi

# Tray icon (amber while the buffer records), which also swaps LosslessCut cuts in
link_units capture-tray.service
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
            "$llc" >"$llc.new" && mv "$llc.new" "$llc"
    fi
fi
echo "Done"
