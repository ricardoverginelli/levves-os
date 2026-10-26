// KWin effect: windows glide to a new place or size instead of jumping there.
// Covers every change KWin or an app makes on its own: quick tiling
// (Meta+arrows), maximize/restore, moving to another monitor, snap assist.
// Dragging or resizing with the mouse isn't animated (the window would trail
// the pointer), nor is anything going to or from fullscreen.
//
// The window is already drawn at its new geometry, so the animation scales it
// from the old size (Size scales around the center) and slides it from the
// old center to the new one.
//
// Install: plasma/apply.sh

"use strict";

// DESIGN.md motion: the house curve (OutQuint) at the panel duration (320ms),
// as these are big on-screen movements, like Yakuake's slide
const curve = QEasingCurve.OutQuint;
let duration;

function loadConfig() {
    duration = animationTime(320);
}

function geometryOf(window) {
    return { x: window.x, y: window.y, width: window.width, height: window.height, fullScreen: window.fullScreen };
}

function isAnimated(window) {
    return (window.normalWindow || window.dialog) && !window.minimized && window.visible
        && window.windowClass.split(" ")[0] !== "yakuake";  // Yakuake slides with its own effect
}

function track(window) {
    window.leavesGeometry = geometryOf(window);
    window.windowFrameGeometryChanged.connect(changed);
}

function changed(window) {
    const from = window.leavesGeometry, to = geometryOf(window);
    window.leavesGeometry = to;
    if (!from || effects.hasActiveFullScreenEffect || !isAnimated(window))
        return;
    if (window.move || window.resize || from.fullScreen || to.fullScreen)
        return;
    if (from.width <= 0 || from.height <= 0)
        return;
    const dx = (from.x + from.width / 2) - (to.x + to.width / 2);
    const dy = (from.y + from.height / 2) - (to.y + to.height / 2);
    if (Math.abs(dx) < 1 && Math.abs(dy) < 1 && from.width === to.width && from.height === to.height)
        return;

    if (window.leavesAnimation)
        cancel(window.leavesAnimation);
    // Translucent windows (Konsole) keep their blur while moving
    window.setData(Effect.WindowForceBlurRole, true);
    window.setData(Effect.WindowForceBackgroundContrastRole, true);
    window.leavesAnimation = animate({
        window: window,
        curve: curve,
        duration: duration,
        animations: [{
            type: Effect.Size,
            from: { value1: from.width, value2: from.height },
            to: { value1: to.width, value2: to.height },
        }, {
            type: Effect.Translation,
            from: { value1: dx, value2: dy },
            to: { value1: 0, value2: 0 },
        }],
    });
}

effects.windowAdded.connect(track);
effects.stackingOrder.forEach(track);

effect.animationEnded.connect(window => {
    delete window.leavesAnimation;
});

effect.configChanged.connect(loadConfig);
loadConfig();
