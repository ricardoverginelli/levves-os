# steam

Makes Steam show as Steam in the task manager instead of one of its games.

Steam's window names no `.desktop` file, so Plasma matches it by command line,
and the game shortcuts Steam makes (`Exec=steam steam://rungameid/…`) match
before `steam.desktop`. A KWin window rule (`kwinrulesrc`, id
`steam-desktop-file`) forces the window's desktop file to `steam`.

## Install

```bash
bash install.sh              # bash install.sh --uninstall to undo
```
