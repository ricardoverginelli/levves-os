#!/usr/bin/bash
# Make browser-router the default browser (see README.md). User-level, no sudo.
# Safe to re-run. Undo: bash install.sh --uninstall [browser.desktop]
# (default: brave-browser.desktop)
set -e
cd "$(dirname "$(readlink -f "$0")")"
. ../lib/install.sh

bin=$local_bin/browser-router
id=browser-router.desktop

if [ "${1:-}" = --uninstall ]; then
    xdg-settings set default-web-browser "${2:-brave-browser.desktop}" 2> >(grep -v qtpaths >&2)
    xdg-mime default "${2:-brave-browser.desktop}" application/xhtml+xml 2> >(grep -v qtpaths >&2)
    rm -f "$apps/$id" "$bin"
    update-desktop-database "$apps" 2>/dev/null || true
    kbuildsycoca6 2>/dev/null || true
    echo "Uninstalled; default browser is ${2:-brave-browser.desktop}"
    exit 0
fi

chmod +x browser-router
mkdir -p "$apps"
link browser-router "$bin"
# Absolute path: the Plasma session's PATH may not include ~/.local/bin
cat >"$apps/$id" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Browser router
Comment=Opens links in the browser picked for the app that opened them
Exec=$bin %U
Icon=web-browser
NoDisplay=true
MimeType=x-scheme-handler/http;x-scheme-handler/https;text/html;application/xhtml+xml;
DESKTOP
update-desktop-database "$apps" 2>/dev/null || true
kbuildsycoca6 2>/dev/null || true
xdg-settings set default-web-browser "$id" 2> >(grep -v qtpaths >&2)
xdg-mime default "$id" application/xhtml+xml 2> >(grep -v qtpaths >&2)
echo "Done: default browser is $(xdg-settings get default-web-browser)"
