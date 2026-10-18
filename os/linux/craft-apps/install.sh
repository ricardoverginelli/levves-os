#!/usr/bin/bash
# Clone, build and add to the app menu the storytold craft apps (PhotoCraft,
# LightCraft, VectorCraft) from your GitHub forks. User-level only, no sudo.
# Safe to re-run: existing clones are left as they are (no pull), rebuilt, and
# their menu entries refreshed.
# Usage: bash install.sh [photocraft lightcraft vectorcraft]   (default: all three)
# Env: CRAFT_SRC (default ~/src), CRAFT_FORK (default ricardoverginelli)
# The command in ~/.local/bin links to target/release, so later builds need no reinstall.
# Undo per app: rm ~/.local/bin/<app> ~/.local/share/applications/ai.storyteller.<app>.desktop \
#   ~/.local/share/mime/packages/ai.storyteller.<app>.mime.xml ~/.local/share/icons/hicolor/*/apps/ai.storyteller.<app>.*
set -e
src=${CRAFT_SRC:-$HOME/src}
fork=${CRAFT_FORK:-ricardoverginelli}
apps=("$@")
[ ${#apps[@]} -gt 0 ] || apps=(photocraft lightcraft vectorcraft)

data=${XDG_DATA_HOME:-$HOME/.local/share}
mkdir -p "$src" "$HOME/.local/bin" "$data/applications" "$data/icons/hicolor" "$data/mime/packages"

for app in "${apps[@]}"; do
    dir=$src/$app
    id=ai.storyteller.$app
    if [ ! -d "$dir" ]; then
        echo "Cloning $fork/$app"
        git clone -q "https://github.com/$fork/$app" "$dir"
        git -C "$dir" remote add upstream "https://github.com/storytold/$app"
    fi

    echo "Building $app"
    (cd "$dir" && cargo build --release -p "$app")

    echo "Installing $app"
    ln -sfn "$dir/target/release/$app" "$HOME/.local/bin/$app"
    cp -r "$dir/assets/app-icon/hicolor/." "$data/icons/hicolor/"
    # Absolute path: the Plasma session's PATH may not include ~/.local/bin
    sed -e "s|^Exec=$app|Exec=$HOME/.local/bin/$app|" -e "s|^TryExec=$app|TryExec=$HOME/.local/bin/$app|" \
        "$dir/packaging/linux/$id.desktop" > "$data/applications/$id.desktop"
    cp "$dir/packaging/linux/$id.mime.xml" "$data/mime/packages/"
done

update-mime-database "$data/mime"
update-desktop-database "$data/applications" 2>/dev/null || true
gtk-update-icon-cache -f -t "$data/icons/hicolor" 2>/dev/null || true
kbuildsycoca6 2>/dev/null || true
echo "Done: ${apps[*]}"
