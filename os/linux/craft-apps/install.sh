#!/usr/bin/bash
# Install the storytold craft apps (PhotoCraft, LightCraft, VectorCraft) from ArtCraft's
# official Flatpak remote (https://getartcraft.com/linux). User-level only, no sudo.
# Safe to re-run: the remote is added once, installed apps are updated.
# Usage: bash install.sh [photocraft lightcraft vectorcraft]   (default: all three)
#        bash install.sh --uninstall [apps]                    (app data in ~/.var/app is kept)
# Other apps on the remote: flatpak remote-ls artcraft-oci
set -e
cd "$(dirname "$(readlink -f "$0")")"
. ../lib/install.sh
need flatpak

remote=artcraft-oci
uninstall=
[ "$1" = --uninstall ] && {
    uninstall=1
    shift
}
apps=("$@")
[ ${#apps[@]} -gt 0 ] || apps=(photocraft lightcraft vectorcraft)
ids=("${apps[@]/#/ai.storyteller.}")

if [ -n "$uninstall" ]; then
    flatpak uninstall --user -y "${ids[@]}"
    echo "Removed: ${apps[*]} (remove the remote with: flatpak remote-delete --user $remote)"
    exit
fi

flatpak remote-add --user --if-not-exists "$remote" https://getartcraft.com/artcraft-oci.flatpakrepo
flatpak install --user -y --noninteractive --or-update "$remote" "${ids[@]}"
echo "Done: ${apps[*]}"
