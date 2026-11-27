#!/usr/bin/bash
# Install Meta+Alt+N: a new Yakuake tab with Claude Code on the business login
# (~/.claude-gorila). Laptop only, where that login lives. Needs kwin/install.sh
# (yakuake-tab and the "New Yakuake Tab" shortcut). User-level, no sudo. Safe to re-run.
# Undo: bash install.sh --uninstall
set -e
cd "$(dirname "$(readlink -f "$0")")"
. ../lib/install.sh

bin=$local_bin/yakuake-business-tab

if [ "${1:-}" = --uninstall ]; then
    remove_launcher_shortcut yakuake-business-tab
    rm -f "$bin"
    echo "Uninstalled"
    exit 0
fi

[ -d ~/.claude-gorila ] || {
    echo "No business login here (~/.claude-gorila)" >&2
    exit 1
}
[ -x ~/.local/bin/yakuake-tab ] || {
    echo "Run kwin/install.sh first" >&2
    exit 1
}

link yakuake-business-tab "$bin"
launcher_shortcut yakuake-business-tab "New Yakuake business Claude tab" "$bin" utilities-terminal \
    "[([$((0x1800004E)), 0, 0, 0],)]" # Meta+Alt+N
echo "Done. Meta+Alt+N opens a Yakuake tab with Claude Code on the business login."
