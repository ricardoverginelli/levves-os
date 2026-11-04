#!/usr/bin/bash
# Install the iD4 mono mic source (see README.md). Desktop only (needs the
# Audient iD4, 2708:0009). User-level, no sudo.
# Restarts PipeWire (a second of silence). Safe to re-run.
# Undo: bash install.sh --uninstall
set -e
cd "$(dirname "$(readlink -f "$0")")"
. ../lib/install.sh

conf=$config/pipewire/pipewire.conf.d/id4-mic-mono.conf
mic=alsa_input.usb-Audient_Audient_iD4-00.HiFi__Mic__source

restart() {
    systemctl --user restart pipewire pipewire-pulse wireplumber
    sleep 2
}

if [ "${1:-}" = --uninstall ]; then
    rm -f "$conf"
    restart
    pactl set-default-source $mic || true
    echo "Uninstalled"
    exit 0
fi

lsusb -d 2708:0009 >/dev/null || { echo "No Audient iD4 (2708:0009) on this machine" >&2; exit 1; }
link id4-mic-mono.conf "$conf"
restart
pactl set-default-source id4_mic_mono
# The replay buffer records default_input, so it has to reopen it
systemctl --user try-restart capture-replay.service
echo "Done"
