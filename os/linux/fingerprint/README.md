# fingerprint

**ASUS laptop only** (`.only-on`). Its fingerprint reader, a FocalTech FT9366 behind a
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

## Updates

`install.sh` adds `excludepkgs=libfprint` to `/etc/dnf/libdnf5.conf.d/`, so a Fedora
update can't silently replace the build and drop the driver. To take a newer Fedora
libfprint: `bash build.sh && sudo bash install.sh` (it builds from the current Fedora
source). If the patch stops applying, check the driver repo for an updated one.
