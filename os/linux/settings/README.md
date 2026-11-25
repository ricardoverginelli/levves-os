# settings

Plasma behavior settings every machine gets, all plain `kwriteconfig6` keys. The look (style,
panels, widgets, wallpaper) is `../plasma/apply.sh`'s; this is how things behave.

| Topic | Setting |
|---|---|
| Keyboard | Holding a key repeats it instead of opening the accent menu; the plasma-keyboard input method is off (it dropped dead-key accents when typing fast). No on-screen keyboard, so not for touchscreens |
| Idle | Locks after 5 minutes without input. On AC the screen never dims or turns off, locked or not; on battery Plasma's defaults still do. Suspend on AC stays off (Plasma's default) |
| Notifications | Popups close after 3.3 s instead of 5 s |
| Calendar reminders | Akonadi's `kalendarac` is off; the Leaves clock widget does reminders (it replayed every missed alarm at login) |

The idle settings apply at once; the keyboard ones after logging out and back in.

Install: `bash install.sh` (no sudo). Undo: `bash install.sh --uninstall` (Plasma's defaults).
