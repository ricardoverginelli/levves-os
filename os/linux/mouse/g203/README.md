# Logitech G203 LIGHTSYNC: Piper

Desktop only. `bash install.sh` installs Piper (libratbag).

The G203 has one onboard profile (DPI, polling rate, buttons, lighting). Settings
written there by Piper survive power-off and work on any PC with nothing running.

Browser configurators like [OpenMouse](https://openmouse.app/) (WebHID) instead
disable the onboard profile and set the mouse live, so everything resets when it
loses power. Don't use them on this mouse. `install.sh` turns the profile back on;
by hand: `ratbagctl list`, then `ratbagctl <name> profile 0 enable`.

Don't run Solaar alongside Piper here: it also sees the G203 and re-applies the
DPI it remembers whenever the mouse connects.
