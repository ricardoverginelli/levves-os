#!/bin/sh
# Login screen (Plasma Login Manager): the Urban Flora wallpaper plus the user's Plasma
# settings, i.e. what System Settings > Login Screen does on Apply and on
# "Apply Plasma Settings". Runs as root: apply.sh calls it through pkexec.
# Usage: install.sh <wallpaper> <user's ~/.config> <Leaves Plasma style folder> <Levves icon theme folder>
set -e
image=$1
config=$2
style=$3
icons=$4
home=/var/lib/plasmalogin
as_greeter="-o plasmalogin -g plasmalogin"

# The greeter can't read the user's home, so the image lives in its own
# shellcheck disable=SC2086 # $as_greeter holds several options, split on purpose (POSIX sh has no arrays)
install -d $as_greeter -m 755 "$home/wallpapers"
find "$home/wallpapers" -mindepth 1 -delete
# shellcheck disable=SC2086 # $as_greeter holds several options, split on purpose (POSIX sh has no arrays)
install $as_greeter -m 644 "$image" "$home/wallpapers/urban-flora.png"
kwriteconfig6 --file /etc/plasmalogin.conf \
    --group Greeter --group Wallpaper --group org.kde.image --group General \
    --key Image "file://$home/wallpapers/urban-flora.png"
chmod 644 /etc/plasmalogin.conf

# Plasma settings: copied when the user has them, removed when they don't
# shellcheck disable=SC2086 # $as_greeter holds several options, split on purpose (POSIX sh has no arrays)
install -d $as_greeter -m 755 "$home/.config" "$home/.config/fontconfig"
for file in kdeglobals plasmarc plasma-localerc kcminputrc kxkbrc \
    kwinoutputconfig.json fontconfig/fonts.conf; do
    if [ -f "$config/$file" ]; then
        # shellcheck disable=SC2086 # $as_greeter holds several options, split on purpose (POSIX sh has no arrays)
        install $as_greeter -m 600 "$config/$file" "$home/.config/$file"
    else
        rm -f "$home/.config/$file"
    fi
done
# The Leaves Plasma style (plasmarc names it), in the greeter's own data folder
# so it stays out of /usr/share, which dnf owns
themes="$home/.local/share/plasma/desktoptheme"
# shellcheck disable=SC2086 # $as_greeter holds several options, split on purpose (POSIX sh has no arrays)
install -d $as_greeter -m 755 "$home/.local" "$home/.local/share" "$home/.local/share/plasma" "$themes"
rm -rf "$themes/leaves"
cp -r "$style" "$themes/leaves"
chown -R plasmalogin:plasmalogin "$themes/leaves"
chmod -R u=rwX,go=rX "$themes/leaves"
# The Levves icon theme (kdeglobals names it) the same way: without it the
# greeter finds no theme and its Sleep/Restart/Shut Down keys draw blank
icon_themes="$home/.local/share/icons"
# shellcheck disable=SC2086 # $as_greeter holds several options, split on purpose (POSIX sh has no arrays)
install -d $as_greeter -m 755 "$icon_themes"
rm -rf "$icon_themes/Levves"
cp -r "$icons" "$icon_themes/Levves"
chown -R plasmalogin:plasmalogin "$icon_themes/Levves"
chmod -R u=rwX,go=rX "$icon_themes/Levves"

# Cached theme colors would outlive the new settings
rm -rf "$home/.cache"
