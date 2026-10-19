# capture

ShareX-style screenshots, GIFs and MP4s for KDE Plasma (Wayland), with the
hotkeys from `sharex/ShareX-*.sxb`.

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
kglobalaccel, and takes `Print`/`Shift+Print` away from Spectacle (its `Meta`
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
- **Upload:** anonymous [catbox.moe](https://catbox.moe), with raw-file links
  like `files.catbox.moe/abc123.png`. Each upload is logged in
  `~/.local/state/capture/history.tsv`.
- **Files:** screenshots and GIFs go to `~/Pictures/Screenshots/YYYY-MM/`, and
  MP4s go to `~/Videos/Screencasts/YYYY-MM/`.
- **Cleanup:** they're disposable. `tmpfiles.conf` (linked into
  `~/.config/user-tmpfiles.d/`) has the daily `systemd-tmpfiles-clean.timer`
  delete captures older than 14 days. Opening a file resets its clock, and
  Spectacle's own files are left alone.
