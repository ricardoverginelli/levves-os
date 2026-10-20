# capture

ShareX-style screenshots, GIFs and MP4s for KDE Plasma (Wayland), with the
hotkeys from `sharex/ShareX-*.sxb`, plus a ShadowPlay-style instant replay.

| Hotkey | Action |
|---|---|
| `Print` | Region → copy image |
| `Ctrl+Print` | Region → upload → copy link |
| `Shift+Print` | Last region → copy image |
| `Shift+Ctrl+Print` | Last region → upload → copy link |
| `Alt+Print` | GIF of region → copy file |
| `Shift+Alt+Print` | GIF of region → upload → copy link |
| `Ctrl+Alt+Print` | GIF of last region → copy file |
| `Shift+Ctrl+Alt+Print` | MP4 of region → copy file |
| `Shift+Ctrl+Alt+U` | Upload clipboard image → copy link |
| `Alt+F10` | Save the last 90 s (instant replay) |
| `Alt+Shift+F10` | Instant replay buffer off / on |
| `Ctrl+Alt+F10` | Open the replay folder |

Recordings stop when any GIF/MP4 hotkey is pressed again. `Esc` cancels a
region selection.

## Install

```bash
sudo dnf copr enable brycensranch/gpu-screen-recorder-git
sudo dnf install gpu-screen-recorder slurp
bash install.sh              # bash install.sh --uninstall to undo
```

`install.sh` links `capture` into `~/.local/bin`, adds one hidden launcher per
hotkey (`~/.local/share/applications/capture-*.desktop`), binds them through
kglobalaccel, enables `capture-replay.service` (systemd user unit, linked
into `~/.config/systemd/user/`), and takes `Print`/`Shift+Print` away from Spectacle (its `Meta`
shortcuts stay).

## How it works

- **Region:** `slurp` picks it, and the region is saved to
  `~/.local/state/capture/last-region` for the "last region" hotkeys.
- **Screenshot:** Spectacle captures the whole desktop in the background, and
  `magick` crops it. Assumes 100% display scaling.
- **Recording:** `gpu-screen-recorder` records the region with NVENC (H.264,
  30 fps for MP4, 15 fps for GIF). GIFs are converted with an ffmpeg palette
  (sierra2_4a dither, as ShareX does). It needs free VRAM: a game filling the
  card stops the encoder from starting, and you get a "GPU memory is full"
  notification.
- **Instant replay:** `capture-replay.service` starts with the Plasma session
  and keeps the last 90 s of the main monitor in RAM (about 560 MB): H.264 CBR
  50 Mbps, 60 fps, a keyframe every second (lossless trims in LosslessCut land
  within 1 s), desktop audio and mic mixed into one AAC track, cursor
  included. The main monitor is the largest connected one, so it survives
  connector renames; while it's turned off (`main-monitor`) the buffer stops
  and waits, it never records another screen. `Alt+F10` saves to
  `~/Videos/Replays/YYYY-MM/` (kept, never auto-deleted), and clicking the
  "Replay saved" notification shows the file in Dolphin. `Alt+Shift+F10` stops
  the buffer until the next login, to free VRAM for a game. Failures notify
  once; the log is `~/.local/state/capture/replay.log`. `Ctrl+Alt+F10` is a VT
  switch in xkb, so keyd turns it into `Ctrl+Alt+F19` (`keyd/gmk104.conf`).
- **Upload:** anonymous [catbox.moe](https://catbox.moe), with raw-file links
  like `files.catbox.moe/abc123.png`. Each upload is logged in
  `~/.local/state/capture/history.tsv`.
- **Files:** screenshots and GIFs go to `~/Pictures/Screenshots/YYYY-MM/`, and
  MP4s go to `~/Videos/Screencasts/YYYY-MM/`.
- **Cleanup:** they're disposable. `tmpfiles.conf` (linked into
  `~/.config/user-tmpfiles.d/`) has the daily `systemd-tmpfiles-clean.timer`
  delete captures older than 14 days. Opening a file resets its clock, and
  Spectacle's own files are left alone.
