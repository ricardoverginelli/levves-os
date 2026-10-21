# browser-router

Opens each link in a browser picked by the app it came from: links from Slack
open in Chrome (work), everything else in Brave (personal).

## Install

```bash
bash install.sh              # bash install.sh --uninstall to undo
```

`install.sh` links `browser-router` into `~/.local/bin`, adds a hidden launcher
(`~/.local/share/applications/browser-router.desktop`) and makes it the
default browser. `--uninstall` makes Brave the default again, or the
`.desktop` name you pass after it.

## Adding an app

Add a line to `rules` before the `*` line: the app's `.desktop` name without
the suffix, then the browser command. Edits apply on the next link, no
reinstall. To find an app's name, open a link from it and check
`~/.local/state/browser-router.log`.

## How it works

Plasma starts the default browser through systemd, so the router's parent
process is never the app that opened the link. Electron apps (Slack, Discord,
Teams, VS Code...) set `CHROME_DESKTOP=<app>.desktop`, which reaches the
router, and that's what the rules match. Apps that don't set it can't be told
apart and always fall under `*`. A launcher can also name its app itself by exporting
`BROWSER_ROUTER_APP=<name>`, which wins over `CHROME_DESKTOP`: that's how two
instances of the same app (e.g. a business VS Code started with its own
`--user-data-dir`) get different browsers.
