# Yakuake on Wayland (Yakuake 26.08)

How Yakuake sizes and animates itself on Wayland, and why the KWin scripts around it
(`os/linux/kwin/yakuake-avoid-fullscreen`, `yakuake-slide`) are built the way they are. Learned
2026-10-18; source read from invent.kde.org `utilities/yakuake` app/mainwindow.cpp.

- Yakuake lays out its contents (tab bar, terminals) at pixel sizes it computes itself and has no resizeEvent handling. Moving/resizing its window from KWin leaves contents sized for the old monitor (cropped / taller than the screen). Fix the input, not the window.
- On toggle it asks KWin `activeOutputName` (when Screen setting = "at mouse") and plasmashell `StrutManager.availableScreenRect(<output>)`; that rect is cached until the next toggle. So the target monitor must be KWin's active output *before* the toggle: the script owns the shortcut (Meta+/, Yakuake's own cleared via kglobalaccel) and calls `workspace.slotSwitchToNextScreen()` first, then `callDBus(... toggleWindowState)`.
- A fullscreen game pulls KWin's active output back intermittently (focus or pointer). The script holds it: re-switches on `workspace.cursorPosChanged` and `windowActivated` until Yakuake's windowAdded (budget 50).
- Yakuake's D-Bus has only `toggleWindowState`; no screen/size setters. Its moveEvent screen-follow doesn't work on Wayland.
- On Wayland Yakuake ignores its animation settings (UseWMAssist/Frames) and always requests KWin Sliding popups from TopEdge; slidingpopups ignores other effects' grabs. Sideways slide = slidingpopups disabled + custom JS effect.
- KWin scripts can't set the active output directly and get no change signal for it (`workspace.activeScreen` is read-only, no notify).
- Yakuake's ToggleToFocus setting does nothing on Wayland (self-activation without an XDG activation token is refused). Focus-instead-of-retract is done in the KWin script via `workspace.activeWindow = yakuake`.
- Wrong height on monitor switch: Yakuake shows with the rect cached from its *previous* toggle (incl. closes), then the async plasmashell reply resizes it, but it can bounce back to the stale size. Fix in the script: after 300 ms of stable geometry (QTimer works in KWin JS scripts), if it doesn't fit its output, retract + reopen once. The visible reopen flicker is accepted.
- Blur while sliding: KWin's blur skips moving windows unless `WindowForceBlurRole` (and `WindowForceBackgroundContrastRole`) is set, so `yakuake-slide` forces them. Stock Scale starts its own open/close animation before our effect grabs the window and clears both flags when its ~200 ms run ends, mid-slide, so the glass dropped for the slide's last ~100 ms. The effect re-sets them from `effects.windowDataChanged`. Found by logging `windowDataChanged` in the effect while recording HDMI-A-1 with `gpu-screen-recorder -w HDMI-A-1` (KMS capture, no prompt) and toggling via kglobalaccel `invokeShortcut "Toggle Yakuake"`; delays, fades and off-screen theories were all wrong.

See also `kwin-scripts.md`.
