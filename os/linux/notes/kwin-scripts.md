# KWin script gotchas (KWin 6.7)

Learned 2026-10-18 building `os/linux/plasma/kwin/leaves-snap-assist`:

- KWin's QML engine caches files by URL and never drops them on script unload/reload, so edits to a script's `main.qml` don't apply until re-login. Fix used: `main.qml` is a thin `Loader` whose source has a `?v=Date.now()` query; to test without re-login, load a copy from a fresh path via `org.kde.kwin.Scripting.loadDeclarativeScript`.
- The cache-busting `Loader` doesn't reach imported modules: KWin reads the Levves module (its qmldir and `Theme.qml`) once per login. A new Levves piece or token used in a KWin script fails with "X is not a type" (or reads `undefined`) until re-login, and the script stops opening. Tell the user before applying such a change, so they re-login right after.
- A `PlasmaCore.Window` created by a KWin script never gets keyboard input (Qt reports it active, but KWin keeps focus on the app, and `Workspace.activeWindow = internalWindow` is refused). Keys need to be grabbed as `KWin.ShortcutHandler`s that exist only while the window is open (inside a `Loader`).
- In QML scripts the window list is `KWin.Workspace.windows` (a property); `windowList()` is JS-script only.
- `console.warn` from scripts shows in `journalctl --user`; `print` does not.
- Shortcuts can be changed live with `gdbus ... org.kde.KGlobalAccel.setForeignShortcutKeys` (Qt key codes, a(ai)); see `os/linux/plasma/apply.sh`. Multi-key a(ai) text form: `[([k1,0,0,0],),([k2,0,0,0],)]` (each key a tuple).
- Global shortcuts with Shift on a symbol key (ABNT2 + keyd GMK104): the combo arrives with Shift consumed into the symbol — Meta+Shift+/ arrives as Meta+? (`wev` shows `Super+Shift+question`, but kglobalaccel matches Meta+question, not Meta+Shift+question). Bind the consumed-modifier variant too; letters (Meta+Shift+N) are unaffected.
- Screen indexes in `workspace.screens` (and `screen=` in window rules) don't follow `kscreen-doctor`'s output numbering. Check them on each machine with a script that does `console.info` on `workspace.screens`, loaded via `qdbus-qt6 org.kde.KWin /Scripting`, then read `journalctl --user`.
