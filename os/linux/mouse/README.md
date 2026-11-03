# Mouse

Each mouse has its own folder, set up only on the machine it's used with:
- `g203/`: Logitech G203 LIGHTSYNC on the desktop, configured with Piper
- `mx-master-3/`: Logitech MX Master 3 on the laptop, configured with Solaar
- `middle-click/` (shared, every machine): middle click like on Windows, no paste and browser autoscroll

## 70-logitech-hidraw.rules (shared)

`bash install.sh` gives the logged-in user access to Logitech hidraw nodes, so
browser configurators (WebHID) can reach the mouse. Not needed by Piper or Solaar.
