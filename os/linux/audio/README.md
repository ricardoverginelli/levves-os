# audio

**Desktop only** (in its basket, `machines/`): needs the Audient iD4.

Audient iD4 fix: its mic (input 1) shows up as a stereo source with the voice on
the left channel only, so recordings (the capture replay buffer, Discord...)
put you in the left ear. `id4-mic-mono.conf` adds a PipeWire mono source, "iD4
Mic (mono)", fed from that left channel, and `install.sh` makes it the default
input. The iD4's second input (right channel) no longer reaches it; pick the
raw iD4 source in an app if you ever need it.

```bash
bash install.sh              # bash install.sh --uninstall to undo
```
