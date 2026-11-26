# syncthing

Keeps `~/.agents` (the shared agent instructions, notes, glossary and skills; ADR 0001) in step
between this machine, the NAS and every other PC. The NAS is the hub and an introducer: pair a
PC with it once and it syncs with the rest.

## Install

Once per NAS, from any PC: `nas/syncthing/install.sh`. Then on each PC:

```bash
sudo dnf -y install syncthing
bash install.sh              # bash install.sh --uninstall to stop it
```

It enables the `syncthing` user service, pairs this machine and the NAS over SSH (`ssh nas`),
and shares the `agents` folder both ways. Then run `agents/install.sh`, which links
`~/.claude/CLAUDE.md` and the skills to `~/.agents`. Safe to re-run.

## Notes

- `.git` isn't synced (`stignore`, copied to `~/.agents/.stignore`): git between machines over
  Syncthing corrupts. The NAS commits `~/.agents` nightly, so history is there:
  `ssh nas git -C .agents log`.
- Web UI: http://localhost:8384 here; the NAS's is on its localhost only
  (`ssh -L 8385:localhost:8384 nas`, then http://localhost:8385).
- Two machines editing one file before they sync gives a `.sync-conflict-…` copy next to it;
  merge it by hand and delete it.
