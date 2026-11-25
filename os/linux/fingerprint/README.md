# fingerprint

**ASUS laptop only** (in its basket, `machines/`). Its fingerprint reader, a FocalTech FT9366 behind a
Realtek RTS5811 bridge (USB `2808:a658`), isn't supported by upstream libfprint. This
builds Fedora's own libfprint package with an open-source driver for it added, so fprintd
and Fedora's fingerprint login (authselect `with-fingerprint`) work unchanged.

```bash
bash build.sh                # rootless podman build, RPMs in ~/.cache/libfprint-ft9366
sudo bash install.sh         # sudo bash install.sh --uninstall to undo
fprintd-enroll               # about 20 touches
fprintd-verify
```

## The driver

`ft9366-driver.patch` comes from
[tattwamashi/libfprint-ft9366-pkg](https://github.com/tattwamashi/libfprint-ft9366-pkg)
(commit `9bdb018`, 2026-10-09). It's `git diff 6f9479c ft9366` in
[tattwamashi/libfprint](https://github.com/tattwamashi/libfprint), which builds on
V8V88V8V88's protocol work, and applies to libfprint 1.94.100. It's written from USB
captures, with no vendor code, and matches on the host with its own matcher, since the
sensor is only about 3x4 mm.

- New code, tested by its author on one laptop. Keep the password as a fallback.
- The sensor sits on the power button: touch it lightly, a firm press can power off.

## Login screen and sudo (`install-pam.sh`)

Fedora's `with-fingerprint` only covers `system-auth` (sudo, polkit, lock screen). The
Plasma Login Manager uses `password-auth`, so it never asks for a finger.
`sudo bash install-pam.sh` (`--uninstall` to undo) adds two things:

- `/etc/pam.d/plasmalogin` (`pam/plasmalogin`) overrides Fedora's file. Type the password
  as usual, or leave it empty, press Enter and touch the sensor. A fingerprint login
  can't unlock KWallet, so the wallet asks for the password afterwards. Recheck this
  file against `/usr/lib/pam.d/plasmalogin` when plasma-login-manager updates.
- `pam/sudo-notify`, run by `pam_exec` from `/etc/pam.d/sudo`. Without a terminal (Claude
  Code's `! <command>`) nobody sees "Place your finger", and sudo looks stuck for 30 s
  before the password dialog. It shows a notification while sudo waits for a finger, and
  closes it when sudo gets in. In a terminal it does nothing.

If the login screen breaks, log in on a text console (Ctrl+Alt+F3, which uses
`/etc/pam.d/login`) and run `sudo bash install-pam.sh --uninstall`.

## Updates

`install.sh` adds `excludepkgs=libfprint` to `/etc/dnf/libdnf5.conf.d/`, so a Fedora
update can't silently replace the build and drop the driver. To take a newer Fedora
libfprint: `bash build.sh && sudo bash install.sh` (it builds from the current Fedora
source). If the patch stops applying, check the driver repo for an updated one.
