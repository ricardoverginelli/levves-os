# Mouse

`bash install.sh` sets up both mice. Shared: each app ignores mice it doesn't see.

## Logitech G203 LIGHTSYNC (desktop): Piper

The G203 has one onboard profile (DPI, polling rate, buttons, lighting). Settings
written there by Piper survive power-off and work on any PC with nothing running.

Browser configurators like [OpenMouse](https://openmouse.app/) (WebHID) instead
disable the onboard profile and set the mouse live, so everything resets when it
loses power. Don't use them on this mouse. `install.sh` turns the profile back on;
by hand: `ratbagctl list`, then `ratbagctl <name> profile 0 enable`.

## Logitech MX Master 3 (laptop): Solaar

This mouse can't store remaps for its extra buttons (gesture button, thumb wheel,
side buttons); even Logi Options does them in software. Solaar must be running:
the Fedora package autostarts it at login, hidden in the tray. Remaps are rules in
Solaar's rule editor, saved to `~/.config/solaar/rules.yaml`. On Plasma Wayland,
rules can't check which app is focused (GNOME only).

## 70-logitech-hidraw.rules

Gives the logged-in user access to Logitech hidraw nodes, so WebHID configurators
can reach the mouse. Not needed by Piper or Solaar.
