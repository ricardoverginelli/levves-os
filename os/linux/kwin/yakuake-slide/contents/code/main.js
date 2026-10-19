// KWin effect: slide Yakuake in from the right edge of its monitor, and back
// out when it retracts.
//
// On Wayland, Yakuake always asks KWin's Sliding popups effect to slide it
// down from the top (its animation settings only apply on X11), and that
// effect doesn't yield to others. So Sliding popups is turned off, which makes
// Yakuake skip the request, and this effect animates it instead. It grabs the
// window, so the Scale/Fade open-close effects leave it alone. Yakuake's own
// settings dock it: Width 30%, Height 100%, Position all the way right.
//
// Install: cp -r yakuake-slide ~/.local/share/kwin/effects/
//   kwriteconfig6 --file kwinrc --group Plugins --key slidingpopupsEnabled false
//   kwriteconfig6 --file kwinrc --group Plugins --key yakuake-slideEnabled true
//   qdbus-qt6 org.kde.KWin /KWin reconfigure

"use strict";

// DESIGN.md motion: 280ms for large panels, closing ~30% faster; OutCubic is
// the nearest named curve to the house curve
const openDuration = animationTime(280);
const closeDuration = animationTime(200);

function isYakuake(window) {
    return window.windowClass.split(" ").includes("org.kde.yakuake") && window.visible;
}

// Docked to the right edge, so its own width takes it fully off its monitor
function offset(window) {
    return window.width;
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
        curve: QEasingCurve.OutCubic,
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
        curve: QEasingCurve.OutCubic,
        duration: closeDuration,
        type: Effect.Translation,
        from: { value1: 0, value2: 0 },
        to: { value1: offset(window), value2: 0 }
    });
});
