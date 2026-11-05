# Drive mirror on Windows (to do)

Written 2026-11-04. Build `os/windows/drive-mirror/` from this plan, then
delete this file once the README section in `CLAUDE.md` replaces it.

## Why
`os/linux/drive-mirror` is a one-way `rclone sync` from Google Drive onto the
"Drive Mirror" HDD. Files added or edited on the disk but never uploaded are
moved to `_rclone-removed/<timestamp>/` on the next run on Fedora. Most of the
editing happens on Windows (Ableton projects in `Arquivos/Ableton Project/`), so
those edits get moved out. That happened on 2026-10-31: the `As the rush comesv6`
files were moved out, restored by hand and uploaded through the browser.

## To do
- [ ] `install.py`: install rclone from the GitHub release
      (`rclone-v*-windows-amd64.zip`). No winget on LTSC. Check the zip's sha256
      against the release `digest` before extracting, like `ahk/install.py`.
      Extract to `%LOCALAPPDATA%\Programs\rclone\` and add it to the user PATH.
- [ ] Create a remote with write access: `rclone config create gdrive-rw drive scope=drive`
      (opens the browser). Keep the Linux `gdrive` remote read-only, so the mirror
      itself still can't change the cloud. Skip this step if `gdrive-rw` already exists.
- [ ] `drive-push.ps1` (+ a `drive-push.cmd` shim on PATH): upload local edits with
      `rclone copy <disk> gdrive-rw: --update`. Use **copy, not sync**, so it never
      deletes anything in the cloud. `--dry-run` passes through to rclone.
- [ ] Find the disk by its label `Drive Mirror` (NTFS serial `C236DF7C`; Linux UUID
      `C4C236E9C236DF7C`). It's `D:` today, but don't hardcode the letter. Refuse to run
      if the disk isn't there.
- [ ] Use the same excludes as the Linux script: `/_rclone-removed/**`,
      `/$RECYCLE.BIN/**`, `/System Volume Information/**`, `/sync.ffs_lock`,
      `desktop.ini`, `--ignore-case`.
- [ ] Use the same `--drive-export-formats docx,xlsx,pptx,svg`, so the mirrored
      `.docx/.xlsx/.pptx` files map back to their Google Docs and aren't uploaded as
      duplicate Office files. Check with `--dry-run` that none of them get queued.
      Don't use `--drive-skip-gdocs`: that would make them look new.
- [ ] Encoding: rclone on Windows already uses the Windows local encoding, which is
      what the Linux script sets with `--local-encoding`. No flag needed, but check
      a name with lookalike characters (`a：b`) maps back to the right file.
- [ ] Logs to `%LOCALAPPDATA%\drive-mirror\`, kept 90 days, same as Linux.
- [ ] Decide: push by hand only, or also a scheduled task (at logon / on shutdown)?
      Running it automatically avoids forgetting before booting Fedora.
- [ ] Wire it up: add an entry to `SCRIPTS` in `os/windows/setup.py`, a line in the
      repo-structure block, and a "Notes per Script" section in `os/windows/CLAUDE.md`.
      Add a pointer in `os/linux/drive-mirror/README.md` ("edited on Windows? run
      `drive-push` before booting Fedora").
- [ ] The rclone shared client ID is being retired during 2026 (see the Linux README).
      Use the same own client ID for both remotes once one is made.
