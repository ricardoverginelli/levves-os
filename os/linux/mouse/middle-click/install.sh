#!/usr/bin/bash
# Middle click like on Windows (see README.md): no paste of selected text, and
# autoscroll in Chrome and Brave. User-level except one policy file (sudo) that
# hides the "unsupported command-line flag" bar. Safe to re-run.
# Log out and back in afterwards.
# Undo: bash install.sh --uninstall
set -e
cd "$(dirname "$(readlink -f "$0")")"

browsers="google-chrome brave-browser"
bin=~/.local/bin
apps=~/.local/share/applications
# Browser policy dirs (Chrome, Brave) for the policy that hides the warning bar
policy_dirs="/etc/opt/chrome/policies/managed /etc/brave/policies/managed"
policy=levves-middle-click.json

if [ "${1:-}" = --uninstall ]; then
    kwriteconfig6 --file kwinrc --group Wayland --key EnablePrimarySelection --delete
    for b in $browsers; do
        rm -f "$bin/$b-stable"
        grep -qs MiddleClickAutoscroll "$apps/$b.desktop" && rm -f "$apps/$b.desktop"
    done
    for d in $policy_dirs; do
        [ -e "$d/$policy" ] && sudo rm -f "$d/$policy"
    done
    echo "Uninstalled; log out and back in to apply"
    exit 0
fi

# System Settings > General Behavior > "Middle Click: Paste selected text"
kwriteconfig6 --file kwinrc --group Wayland --key EnablePrimarySelection false

mkdir -p "$bin" "$apps"
for b in $browsers; do
    [ -x "/usr/bin/$b-stable" ] || continue
    ln -sf "$PWD/browser-autoscroll" "$bin/$b-stable"
    # Menu and taskbar launchers use the full /usr/bin path, so point them at
    # the wrapper. A copy: re-run after an update changes the system one.
    sed "s|^Exec=/usr/bin/|Exec=$bin/|; 1a # Made by levves mouse/middle-click (MiddleClickAutoscroll)" \
        "/usr/share/applications/$b.desktop" > "$apps/$b.desktop"
done

# The flag makes Chrome and Brave show "You are using an unsupported
# command-line flag" on every start; this policy hides that bar.
for d in $policy_dirs; do
    case $d in */chrome/*) b=google-chrome ;; *) b=brave-browser ;; esac
    [ -x "/usr/bin/$b-stable" ] || continue
    sudo mkdir -p "$d"
    echo '{ "CommandLineFlagSecurityWarningsEnabled": false }' | sudo tee "$d/$policy" >/dev/null
done
echo "Done; log out and back in, and fully quit Chrome and Brave first"
