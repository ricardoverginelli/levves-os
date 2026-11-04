#!/usr/bin/bash
# Install the main-monitor toggle hotkey (see README.md). User-level, no sudo.
# Safe to re-run. Undo: bash install.sh --uninstall
set -e
cd "$(dirname "$(readlink -f "$0")")"
. ../lib/install.sh

bin=$local_bin/main-monitor
id=main-monitor-toggle

if [ "${1:-}" = --uninstall ]; then
    remove_launcher_shortcut $id
    rm -f "$bin"
    echo "Uninstalled"
    exit 0
fi

need kscreen-doctor jq

chmod +x main-monitor
link main-monitor "$bin"
launcher_shortcut $id "Toggle main monitor" "$bin toggle" video-display "[([$((0x1200004D)), 0, 0, 0],)]"  # Meta+Shift+M
echo "Done: Meta+Shift+M toggles the main monitor"
