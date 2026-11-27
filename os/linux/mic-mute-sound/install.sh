#!/usr/bin/bash
# Install mic-mute-sound (see README.md). User-level, no sudo. Safe to re-run.
# Undo: bash install.sh --uninstall
set -e
cd "$(dirname "$(readlink -f "$0")")"
. ../lib/install.sh

bin=$local_bin/mic-mute-sound
sounds=$data/mic-mute-sound

if [ "${1:-}" = --uninstall ]; then
    unlink_units mic-mute-sound.service
    rm -rf "$bin" "$sounds"
    echo "Uninstalled"
    exit 0
fi

need pactl pw-play ffmpeg

# Two quick notes each: falling for muted, rising for unmuted
tone() { # <out> <first Hz> <second Hz>
    ffmpeg -loglevel error -y \
        -f lavfi -i "sine=f=$2:d=0.07" -f lavfi -i "sine=f=$3:d=0.09" \
        -filter_complex "[0]afade=t=out:st=0.05:d=0.02[a];[1]afade=t=out:st=0.05:d=0.04[b];[a][b]concat=n=2:v=0:a=1,volume=0.35" \
        -c:a libvorbis "$1"
}
mkdir -p "$sounds"
tone "$sounds/muted.oga" 880 587
tone "$sounds/unmuted.oga" 587 880

chmod +x mic-mute-sound
link mic-mute-sound "$bin"
link_units mic-mute-sound.service
systemctl --user enable mic-mute-sound.service
systemctl --user restart mic-mute-sound.service
echo "Done"
