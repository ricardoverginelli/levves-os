# mic-mute-sound

A brief sound cue whenever the default mic is muted (falling two-note tone) or
unmuted (rising), so a mic-mute key gives feedback without looking at the screen.
It watches PipeWire (`pactl subscribe`), so it works however the mic gets muted:
Plasma's mic-mute key (Numpad 5 on the GMK104, see `../keyd/gmk104.conf`), the
volume applet, or a laptop's own mic key. Switching default mics doesn't beep.

Install: `bash install.sh` (user service, no sudo; needs `ffmpeg` to make the tones
into `~/.local/share/mic-mute-sound/`). Undo: `bash install.sh --uninstall`.
