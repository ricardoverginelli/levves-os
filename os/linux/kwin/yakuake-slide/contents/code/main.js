// KWin effect: slide Yakuake in from the left edge of its monitor, and back
// out when it retracts.
//
// On Wayland, Yakuake always asks KWin's Sliding popups effect to slide it
// down from the top (its animation settings only apply on X11), and that
// effect doesn't yield to others. So Sliding popups is turned off, which makes
// Yakuake skip the request, and this effect animates it instead. It grabs the
// window, so the Scale/Fade open-close effects leave it alone. Yakuake's own
// settings dock it: Width 30%, Height 100%, Position all the way left (the
// right edge is the Leaves side panel's).
//
// Install: bash install.sh in os/linux/kwin (plasma/apply.sh runs it too)

"use strict";

// DESIGN.md motion: the house curve, 320ms for large panels, closing ~30% faster
const openDuration = animationTime(320);
const closeDuration = animationTime(220);

function isYakuake(window) {
    return window.windowClass.split(" ").includes("org.kde.yakuake") && window.visible;
}

// Docked to the left edge, so its own width takes it fully off its monitor
function offset(window) {
    return -window.width;
}

effects.windowAdded.connect(window => {
    if (!isYakuake(window))
        return;
    window.setData(Effect.WindowAddedGrabRole, effect);
    if (window.slideOut) {
        cancel(window.slideOut);
        delete window.slideOut;
    }
    window.slideIn = animate({
        window: window,
        curve: QEasingCurve.OutQuint,
        duration: openDuration,
        type: Effect.Translation,
        from: { value1: offset(window), value2: 0 },
        to: { value1: 0, value2: 0 }
    });
});

effects.windowClosed.connect(window => {
    if (!isYakuake(window))
        return;
    window.setData(Effect.WindowClosedGrabRole, effect);
    if (window.slideIn) {
        cancel(window.slideIn);
        delete window.slideIn;
    }
    window.slideOut = animate({
        window: window,
        curve: QEasingCurve.OutQuint,
        duration: closeDuration,
        type: Effect.Translation,
        from: { value1: 0, value2: 0 },
        to: { value1: offset(window), value2: 0 }
    });
});
