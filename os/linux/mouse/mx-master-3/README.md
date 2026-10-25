# Logitech MX Master 3: Solaar

Laptop only. `bash install.sh` installs Solaar.

This mouse can't store remaps for its extra buttons (gesture button, thumb wheel,
side buttons); even Logi Options does them in software. Solaar must be running:
the Fedora package autostarts it at login, hidden in the tray, and it re-applies
settings whenever the mouse connects. Remaps are rules in Solaar's rule editor,
saved to `~/.config/solaar/rules.yaml`. On Plasma Wayland, rules can't check
which app is focused (GNOME only).
