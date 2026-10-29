# reboot-to-windows

**Desktop only** (`.only-on`): the desktop dual-boots Windows 11 from the X15 SSD.

"Reboot to Windows" in the app menu (or KRunner, or `reboot-to-windows` in a
terminal) restarts straight into Windows, once. The next boot after that follows
the normal order again (Fedora first).

```bash
bash install.sh              # bash install.sh --uninstall to undo
```

## Why not the GRUB entry
With Secure Boot on, picking "Windows Boot Manager" in GRUB gives a black screen:
Windows hangs when started through shim/GRUB (confirmed 2026-10-29: it boots
from GRUB with Secure Boot off, and always boots when the firmware starts it).
So this skips GRUB: it sets UEFI `BootNext` to the firmware's Windows Boot
Manager entry, and the firmware starts Windows itself. F11 at power-on (MSI boot
menu) does the same by hand.

## How it works
- `efi-bootnext-windows` finds the "Windows Boot Manager" entry in `efibootmgr`
  and sets `BootNext` to it. It needs root, so `install.sh` copies it root-owned
  to `/usr/local/sbin/` and allows it without a password in
  `/etc/sudoers.d/reboot-to-windows` (it takes no arguments).
- `reboot-to-windows` asks first (`-y` skips that), runs the helper with
  `sudo -n`, then asks Plasma to log out and reboot so apps can save.
- If an app cancels the logout, `BootNext` stays set: the next reboot goes to
  Windows anyway.
