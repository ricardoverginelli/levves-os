# media-actions

Middle-click a video or image in Dolphin to get a small menu at the pointer:

- **Videos:** Cut (opens LosslessCut) or Convert ▸ MP4 / MP3 / GIF
- **Images:** Convert ▸ PNG / JPG (GIFs also get MP4)

The format the file already is gets left out. The result goes next to the original
(`name (1).ext` if that name is taken), with a notification and a "Show in folder" button.
Keys: arrows, Enter, Left/Backspace to go back, Esc to close.

## Install

```bash
bash install.sh              # bash install.sh --uninstall to undo
```

Needs `ffmpeg`, `ImageMagick`, `python3-pyside6`, `layer-shell-qt`, and LosslessCut
(Flathub `no.mifi.losslesscut`) for Cut.

## How it works

- Dolphin opens a middle-clicked file with the **second** app in that file type's list.
  `install.sh` pins the current default (Dragon Player, Gwenview…) first in
  `~/.config/mimeapps.list` and puts `media-actions.desktop` second.
- `Menu.qml` is a transparent layer-shell overlay over the monitor. It reads the pointer
  position when it appears and puts the menu there. A click outside closes it.
- MP4: remuxed without re-encoding when the codecs already fit (H.264/HEVC with AAC/MP3,
  e.g. OBS or replay MKVs). Otherwise it's encoded with NVENC, or x264 if that fails.
- GIF: 15 fps, at most 960px wide, the same palette pass as `capture`.
- PNG/JPG: ImageMagick, first frame only. JPG puts transparent areas on white.
