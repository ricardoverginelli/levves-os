# nordvpn

Shared (all machines that have NordVPN installed).

`vpnon` connects (optional server/country, e.g. `vpnon Brazil`) and `vpnoff`
disconnects. Neither asks for a password. The NordVPN daemon (~95 MB RAM) only
runs between the two: it no longer starts at boot.

```bash
bash install.sh              # bash install.sh --uninstall to undo
```

Needs the `nordvpn` package and the user in the `nordvpn` group (the NordVPN
installer does that; log out and back in after it).

## How it works
- `install.sh` links `vpnon`/`vpnoff` into `~/.local/bin` and disables
  `nordvpnd.service` and `nordvpnd.socket`, so nothing starts the daemon at boot.
  Don't enable the socket instead: the first `nordvpn` command would start the
  daemon and it would keep running until reboot.
- Starting and stopping the units needs root, so `install.sh` writes
  `/etc/sudoers.d/nordvpn` (checked with `visudo` first) allowing exactly the
  two `systemctl` command lines in `vpnon`/`vpnoff` without a password. There
  are no wildcards, so no other arguments or units get through. If you change
  those lines in the scripts, change the rule to match and re-run `install.sh`,
  or the password prompt comes back.
- `nordvpn connect`/`disconnect` themselves need no root, only the `nordvpn`
  group.

## Checking it
`sudo -l` doesn't show whether a password is needed, so test the real command
with the sudo cache cleared (harmless when the daemon is already stopped):

```bash
sudo -k; sudo -n systemctl stop nordvpnd.socket nordvpnd.service nordvpnd-killswitch.service && echo ok
```
