#!/usr/bin/bash
# Install the middle-click media menu (see README.md). User-level, no sudo.
# Safe to re-run. Undo: bash install.sh --uninstall
set -e
cd "$(dirname "$(readlink -f "$0")")"

bin=$HOME/.local/bin/media-actions
apps=${XDG_DATA_HOME:-$HOME/.local/share}/applications
desktop=media-actions.desktop
mimeapps=${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list

videos="video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo video/mpeg
video/x-flv video/mp2t video/ogg video/3gpp video/x-ms-wmv video/x-m4v"
images="image/png image/jpeg image/webp image/avif image/bmp image/tiff image/gif
image/heif image/heic image/jxl"

added() {  # mime → its Added Associations list, without us
    kreadconfig6 --file "$mimeapps" --group "Added Associations" --key "$1" |
        tr ';' '\n' | grep -vx -e "$desktop" -e '' | paste -sd ';' || true
}

if [ "${1:-}" = --uninstall ]; then
    for mime in $videos $images; do
        rest=$(added "$mime")
        if [ -n "$rest" ]; then
            kwriteconfig6 --file "$mimeapps" --group "Added Associations" --key "$mime" "$rest;"
        else
            kwriteconfig6 --file "$mimeapps" --group "Added Associations" --key "$mime" --delete
        fi
    done
    rm -f "$bin" "$apps/$desktop"
    kbuildsycoca6 >/dev/null 2>&1 || true
    echo "Uninstalled"
    exit 0
fi

for cmd in ffmpeg ffprobe magick notify-send kreadconfig6 kwriteconfig6; do
    command -v "$cmd" >/dev/null || { echo "Missing: $cmd" >&2; exit 1; }
done
python3 -c "import PySide6" 2>/dev/null || { echo "Missing: python3-pyside6" >&2; exit 1; }
[ -d /usr/lib64/qt6/qml/org/kde/layershell ] || { echo "Missing: layer-shell-qt" >&2; exit 1; }

mkdir -p "$(dirname "$bin")" "$apps"
ln -sf "$PWD/media-actions" "$bin"
cat > "$apps/$desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Cut or Convert
Comment=Cut with LosslessCut, or convert to MP4, MP3, GIF, PNG or JPG
Exec=$bin %F
Icon=mingcute-transfer-horizontal-fill
NoDisplay=true
MimeType=$(echo $videos $images | tr ' ' ';');
EOF

# Dolphin's middle-click opens the second app in a type's list: keep the current
# default first (pinned, so adding us can't change it) and put this menu second
for mime in $videos $images; do
    default=$(kreadconfig6 --file "$mimeapps" --group "Default Applications" --key "$mime")
    default=${default%%;*}
    [ -n "$default" ] || default=$(xdg-mime query default "$mime" 2>/dev/null || true)
    [ "$default" != "$desktop" ] || default=
    rest=$(added "$mime" | tr ';' '\n' | grep -vx -e "$default" | paste -sd ';' || true)
    list="${default:+$default;}$desktop;${rest:+$rest;}"
    kwriteconfig6 --file "$mimeapps" --group "Added Associations" --key "$mime" "$list"
    [ -z "$default" ] ||
        kwriteconfig6 --file "$mimeapps" --group "Default Applications" --key "$mime" "$default"
done
kbuildsycoca6 >/dev/null 2>&1 || true

# The menu's MingCute icons
python3 ../plasma/icons/install.py >/dev/null

echo "Installed: middle-click a video or image in Dolphin"
