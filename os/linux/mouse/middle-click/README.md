# Middle click like on Windows (shared)

`bash install.sh` (`--uninstall` to undo), then log out and back in.

- **No paste:** Plasma pastes the last selected text on middle click (System
  Settings > General Behavior > "Middle Click: Paste selected text"). Turned off,
  so middle-dragging Figma's canvas pans it instead of pasting into it. Links
  still open in a new tab and tabs still close on middle click.
- **Autoscroll in Chrome and Brave:** middle click on a page then move the mouse
  to scroll, as on Windows. Chromium has it off on Linux; a wrapper in
  `~/.local/bin` (also used by `browser-router`) starts each browser with
  `--enable-blink-features=MiddleClickAutoscroll`, and local copies of their
  `.desktop` files point the menu and taskbar at it. The flag only applies when
  the browser starts from nothing, so quit it fully first. Re-run after a
  browser update changes its `.desktop` file. The flag makes the browsers show
  "You are using an unsupported command-line flag" on start, so the script also
  sets the `CommandLineFlagSecurityWarningsEnabled` policy to false (a file in
  `/etc/opt/chrome/policies/managed` and `/etc/brave/policies/managed`; asks for
  sudo). Side effect: the browser menu says it is managed by your organization.
