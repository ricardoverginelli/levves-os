# drive-mirror

**Desktop only** (`.only-on`): needs the "Drive Mirror" HDD (Seagate ST1000DM003, NTFS).

A one-way copy of Google Drive (My Drive) on the HDD, kept up to date daily by
rclone. It replaces the FreeFileSync mirror that ran on Windows. The disk stays
NTFS so Windows can still read it.

```bash
sudo dnf install rclone
bash install.sh              # bash install.sh --uninstall to undo
drive-mirror --dry-run       # preview; plain `drive-mirror` syncs now
```

## One-time setup
- **Mount:** this line in `/etc/fstab` mounts the disk at `/mnt/drive-mirror`
  (`nofail`, so boot doesn't wait if the disk is missing):
  ```
  UUID=C4C236E9C236DF7C  /mnt/drive-mirror  ntfs-3g  uid=1000,gid=1000,umask=022,windows_names,nofail,x-systemd.device-timeout=10s  0 0
  ```
- **Google account:** `rclone config create gdrive drive scope=drive.readonly`
  opens the browser to sign in. Read-only access, so the mirror can never change
  the cloud. rclone's shared client ID is being retired during 2026; when it
  stops working, make your own (https://rclone.org/drive/#making-your-own-client-id)
  and run `rclone config update gdrive client_id=... client_secret=...`.

## What it does
- `rclone sync gdrive: /mnt/drive-mirror`: new and changed files are copied
  down, and files gone from the cloud are removed from the disk.
- Nothing is deleted outright: removed or overwritten files are moved to
  `_rclone-removed/<timestamp>/` on the disk. Clean that out by hand now and then.
- Google Docs/Sheets/Slides are saved as .docx/.xlsx/.pptx.
- Windows leftovers (`$RECYCLE.BIN`, `System Volume Information`, `desktop.ini`,
  `sync.ffs_lock`) are left alone.
- Logs: `~/.local/state/drive-mirror/`, kept 90 days.
- The timer runs daily (catches up after boot) and skips the run if the
  disk isn't mounted. `systemctl --user list-timers drive-mirror` shows the next run.

## Mounted read-only?
If Windows used the disk and shut down with fast startup on, ntfs-3g mounts it
read-only and the script refuses to run. Either boot Windows and run
`shutdown /s /t 0`, or (discarding Windows' cached writes to this disk):
`sudo umount /mnt/drive-mirror && sudo ntfsfix /dev/disk/by-uuid/C4C236E9C236DF7C && sudo mount /mnt/drive-mirror`.
Turning off fast startup in Windows avoids it for good.
