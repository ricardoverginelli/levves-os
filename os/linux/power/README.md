# power

Idle behavior on every machine: the session locks after 5 minutes without input, plugged in
or on battery. On AC power the screen never dims or turns off, locked or not, so a monitor
showing the lock screen stays lit. On battery, Plasma's defaults still dim and turn it off.
Suspend on AC stays off (Plasma's default for desktops).

Settings: `kscreenlockerrc` `[Daemon]` and `powerdevilrc` `[AC][Display]`; both daemons reload
them, no logout needed.

Install: `bash install.sh` (no sudo). Undo: `bash install.sh --uninstall` (Plasma's defaults).
