#!/usr/bin/bash
# Install mic-mute-sound (see README.md). User-level, no sudo. Safe to re-run.
# Undo: bash install.sh --uninstall
set -e
cd "$(dirname "$(readlink -f "$0")")"

bin=$HOME/.local/bin/mic-mute-sound
units=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user
sounds=${XDG_DATA_HOME:-$HOME/.local/share}/mic-mute-sound

if [ "${1:-}" = --uninstall ]; then
    systemctl --user disable --now mic-mute-sound.service 2>/dev/null || true
    rm -rf "$bin" "$units/mic-mute-sound.service" "$sounds"
    systemctl --user daemon-reload
    echo "Uninstalled"
    exit 0
fi

for cmd in pactl pw-play ffmpeg; do
    command -v $cmd >/dev/null || { echo "Missing $cmd"; exit 1; }
done

# Two quick notes each: falling for muted, rising for unmuted
tone() {  # <out> <first Hz> <second Hz>
    ffmpeg -loglevel error -y \
        -f lavfi -i "sine=f=$2:d=0.07" -f lavfi -i "sine=f=$3:d=0.09" \
        -filter_complex "[0]afade=t=out:st=0.05:d=0.02[a];[1]afade=t=out:st=0.05:d=0.04[b];[a][b]concat=n=2:v=0:a=1,volume=0.35" \
        -c:a libvorbis "$1"
}
mkdir -p "$(dirname "$bin")" "$units" "$sounds"
tone "$sounds/muted.oga" 880 587
tone "$sounds/unmuted.oga" 587 880

chmod +x mic-mute-sound
ln -sfn "$PWD/mic-mute-sound" "$bin"
ln -sfn "$PWD/mic-mute-sound.service" "$units/mic-mute-sound.service"
systemctl --user daemon-reload
systemctl --user enable mic-mute-sound.service
systemctl --user restart mic-mute-sound.service
echo "Done"
