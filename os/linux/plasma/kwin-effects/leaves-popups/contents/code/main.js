// KWin effect: Plasma popups (tray items, the clock, the network popup…) open
// out of the panel they belong to: they slide 8px from its edge while fading
// in, and slide back into it as they close (DESIGN.md Motion, "Drop").
//
// They're applet popups, which KWin's Fading popups effect only fades; this
// effect claims them, so that one leaves them alone. Menus and tooltips keep
// their stock fade.
//
// A clip reveal from the panel's edge ("Unfurl") was tried and dropped: KWin
// draws the glass blur at full size first, so an empty pane flashes.
//
// Install: plasma/apply.sh

"use strict";

// DESIGN.md motion: the house curve (OutQuint), popup 240ms, closing 170ms
const curve = QEasingCurve.OutQuint;
const shift = 8;
let openDuration, closeDuration;

function loadConfig() {
    openDuration = animationTime(240);
    closeDuration = animationTime(170);
}

function isPopup(window) {
    return window.appletPopup && window.visible;
}

// Offset toward the monitor edge the popup sits against (its panel's edge): the nearest one
function offset(window) {
    const screen = window.screen.geometry;
    const edges = [
        { value1: 0, value2: -shift, gap: window.y - screen.y },
        { value1: 0, value2: shift, gap: screen.y + screen.height - (window.y + window.height) },
        { value1: -shift, value2: 0, gap: window.x - screen.x },
        { value1: shift, value2: 0, gap: screen.x + screen.width - (window.x + window.width) },
    ];
    const nearest = edges.reduce((a, b) => b.gap < a.gap ? b : a);
    return { value1: nearest.value1, value2: nearest.value2 };
}

function stop(window) {
    for (const key of ["opening", "closing"]) {
        if (window[key]) {
            cancel(window[key]);
            delete window[key];
        }
    }
}

// Slide and fade for opening (from the panel to its place) or closing (the reverse).
// KWin's blur skips windows that are moving unless they force it, which made
// the glass go clear during the slide and snap back after; forcing it keeps
// the blur on the popup (faded with it) the whole way, as Sliding popups does.
// The flags stay: they only matter while a popup is moving.
function play(window, opening) {
    window.setData(Effect.WindowForceBlurRole, true);
    window.setData(Effect.WindowForceBackgroundContrastRole, true);
    const away = offset(window);
    const home = { value1: 0, value2: 0 };
    const duration = opening ? openDuration : closeDuration;
    return [
        animate({
            window: window,
            curve: curve,
            duration: duration,
            type: Effect.Translation,
            from: opening ? away : home,
            to: opening ? home : away,
        }),
        animate({
            window: window,
            curve: curve,
            duration: duration,
            type: Effect.Opacity,
            from: opening ? 0 : 1,
            to: opening ? 1 : 0,
        }),
    ];
}

effects.windowAdded.connect(window => {
    if (effects.hasActiveFullScreenEffect || !isPopup(window))
        return;
    if (!effect.grab(window, Effect.WindowAddedGrabRole, true))
        return;
    stop(window);
    window.opening = play(window, true);
});

effects.windowClosed.connect(window => {
    if (effects.hasActiveFullScreenEffect || !isPopup(window) || window.skipsCloseAnimation)
        return;
    if (!effect.grab(window, Effect.WindowClosedGrabRole, true))
        return;
    stop(window);
    window.closing = play(window, false);
});

effect.configChanged.connect(loadConfig);
loadConfig();
