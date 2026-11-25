# instant-replay

A ShadowPlay-style instant replay for KDE Plasma (Wayland): while a game runs, the
last 60 s of the main monitor stay in RAM, ready to save. Split from `capture/`
(screenshots, GIFs, MP4s), which every machine has; this one is optional.

| Hotkey | Action |
|---|---|
| `Alt+F10` | Save the last 60 s (while a game runs) |
| `Alt+Shift+F10` | Replay buffer off / on |
| `Ctrl+Alt+F10` | Open the replay folder |

A tray icon shows the buffer: amber while it records, white while it's on and
waiting for a game, faint when it's turned off. Clicking it opens the replay
folder; its menu saves a replay and turns the buffer off / on.

## Install

```bash
sudo dnf copr enable brycensranch/gpu-screen-recorder-git
sudo dnf install gpu-screen-recorder python3-pyside6
bash install.sh              # bash install.sh --uninstall to undo
```

`install.sh` links `instant-replay` into `~/.local/bin`, adds a hidden launcher per
hotkey, enables `capture-replay.service` and `capture-tray.service` (systemd user
units, linked into `~/.config/systemd/user/`) and sets up LosslessCut (below; close
it first). The unit names, hotkey ids (`capture-replay-*`) and state folder
(`~/.local/state/capture/`) are capture's from before the split, so nothing moved.

## How it works

- **Instant replay:** `capture-replay.service` starts with the Plasma session
  and, only while a game runs, keeps the last 60 s of the main monitor in RAM
  (about 375 MB). A game is anything Steam launched (native, Proton or a
  non-Steam shortcut: its `reaper SteamLaunch AppId=` process), plus the
  process names in `instant-replay`'s `other_games` (PokeXGames' `pxgme-linux`),
  fullscreen or not; the buffer starts within 5 s and stays on for 60 s after
  the game closes, so its end can still be saved. The rest of the time nothing
  records. H.264 CBR 50 Mbps, 60 fps, a keyframe every second (lossless trims
  in LosslessCut land within 1 s), desktop audio and mic mixed into one AAC
  track, cursor included. The main monitor is the largest connected one, so it
  survives connector renames; while it's turned off (`main-monitor`) the
  buffer stops and waits, it never records another screen. `Alt+F10` saves to
  `~/Videos/Replays/YYYY-MM/` (kept, never auto-deleted), and clicking the
  "Replay saved" notification shows the file in Dolphin. `Alt+Shift+F10` stops
  the buffer until the next login, to free VRAM for a game. Where
  `~/.config/capture/replay-off-by-default` exists (set by `capture-replay-off/`,
  for machines that rarely game), `install.sh` leaves the service disabled, so
  the buffer is off at login and `Alt+Shift+F10` turns it on until logout. Failures notify
  once; the log is `~/.local/state/capture/replay.log`. `Ctrl+Alt+F10` is a VT
  switch in xkb, so keyd turns it into `Ctrl+Alt+F19` (`keyd/gmk104.conf`).
- **Tray:** `replay-tray` (PySide6, `capture-tray.service`) checks every 2 s
  whether the buffer's recorder is running (`replay.pid`) and the service is
  active, and tints `mingcute-live-fill` with the `DESIGN.md` `accent`, `text`
  or `text-faint` color.
- **LosslessCut cuts replace the file:** LosslessCut refuses to write over the
  file it has open, so `install.sh` sets it to save no `.llc` project files,
  export a cut as `X-cut.mp4` and close the file afterwards. `replay-tray`
  watches `~/Videos/Replays` and `~/Videos/Screencasts`; once `X-cut.mp4` stops
  changing and nothing has it open, `X.mp4` goes to the Trash and the cut takes
  its name. Several segments (`X-cut-seg1.mp4`...) are left as they are, original
  kept. LosslessCut's own "trash source file" is left off: in the Flatpak its
  trash is `rm`, so the original would be gone for good.
