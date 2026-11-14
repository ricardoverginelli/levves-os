#!/usr/bin/bash
# Instant replay buffer off by default on this machine (laptop only, where games
# are rare): login leaves it off, Alt+Shift+F10 turns it on until logout. Sets the
# marker capture/install.sh checks, so re-running that keeps it off.
# User-level, no sudo. Safe to re-run. Undo: bash install.sh --uninstall
set -e
cd "$(dirname "$(readlink -f "$0")")"
. ../lib/install.sh

marker=$config/capture/replay-off-by-default

if [ "${1:-}" = --uninstall ]; then
    rm -f "$marker"
    systemctl --user enable --now capture-replay.service
    echo "Uninstalled: the replay buffer starts at login again"
    exit 0
fi

mkdir -p "$(dirname "$marker")"
touch "$marker"
systemctl --user disable --now capture-replay.service 2>/dev/null || true
# Disabling a linked unit removes its link too; put it back so Alt+Shift+F10 can start it
(cd ../capture && link_units capture-replay.service)
echo "Done. The replay buffer is off at login; Alt+Shift+F10 turns it on until logout."
