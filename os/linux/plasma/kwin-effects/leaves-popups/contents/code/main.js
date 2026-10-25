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
// Leaves windows (the launcher, the side panel) are plasmashell's undecorated
// normal windows: panels, popups, OSDs and notifications have their own types,
// settings windows have a frame, and a layer-shell surface can't carry a title
// to tell them apart by. One docked to a monitor edge (the side panel) slides
// all the way in from that edge, like Yakuake; a free one (the launcher)
// drops from the top bar, where its button is.
//
// Install: plasma/apply.sh

"use strict";

// DESIGN.md motion: the house curve (OutQuint); popups 240/170ms, panels 320/220ms
const curve = QEasingCurve.OutQuint;
const shift = 8;
let popupOpen, popupClose, panelOpen, panelClose;

function loadConfig() {
    popupOpen = animationTime(240);
    popupClose = animationTime(170);
    panelOpen = animationTime(320);
    panelClose = animationTime(220);
}

function isLeavesWindow(window) {
    return window.windowClass.split(" ")[0] === "plasmashell" && window.normalWindow && !window.hasDecoration;
}

function isAnimated(window) {
    return (window.appletPopup || isLeavesWindow(window)) && window.visible;
}

// The monitor edge the window sits against (its panel's edge): the nearest one.
// A tall panel docked right also touches the bottom (and the top, without a bar
// above it), so among edges it's flush with whose opposite side is free, the
// one it's thinnest against wins: a panel 22% of the screen wide and nearly
// full height is docked right. dx/dy point away from the screen, out through
// that edge; extent is the share of the screen the window covers across it.
function nearestEdge(window) {
    const screen = window.screen.geometry;
    const tall = window.height / screen.height, wide = window.width / screen.width;
    const edges = [
        { dx: 0, dy: -1, gap: window.y - screen.y, extent: tall },
        { dx: 0, dy: 1, gap: screen.y + screen.height - (window.y + window.height), extent: tall },
        { dx: -1, dy: 0, gap: window.x - screen.x, extent: wide },
        { dx: 1, dy: 0, gap: screen.x + screen.width - (window.x + window.width), extent: wide },
    ];
    const opposite = i => edges[i ^ 1];  // top↔bottom, left↔right
    const docked = edges.filter((e, i) => e.gap <= 1 && opposite(i).gap > 1);
    if (docked.length)
        return docked.reduce((a, b) => b.extent < a.extent ? b : a);
    return edges.reduce((a, b) => b.gap < a.gap ? b : a);
}

// The side of a popup next to a panel (dock window), pointing into the panel:
// a tray popup at the screen's right end still comes from the bar above. Bar
// popups float a few pixels off their panel (DESIGN.md), so "next to" allows a gap.
function panelSide(window) {
    const near = (a, b) => Math.abs(a - b) <= 8;
    const overlaps = (a0, a1, b0, b1) => a0 < b1 && b0 < a1;
    for (const d of effects.stackingOrder) {
        if (!d.dock || d.screen !== window.screen)
            continue;
        const across = overlaps(window.x, window.x + window.width, d.x, d.x + d.width);
        const along = overlaps(window.y, window.y + window.height, d.y, d.y + d.height);
        if (across && near(window.y, d.y + d.height))
            return { dx: 0, dy: -1 };
        if (across && near(window.y + window.height, d.y))
            return { dx: 0, dy: 1 };
        if (along && near(window.x, d.x + d.width))
            return { dx: -1, dy: 0 };
        if (along && near(window.x + window.width, d.x))
            return { dx: 1, dy: 0 };
    }
    return null;
}

// Where the window starts (opening) or ends (closing), and how
function motion(window) {
    if (window.appletPopup) {
        const dir = panelSide(window) ?? nearestEdge(window);
        return {
            away: { value1: dir.dx * shift, value2: dir.dy * shift },
            open: popupOpen, close: popupClose, fade: true,
        };
    }
    const edge = nearestEdge(window);
    if (isLeavesWindow(window) && edge.gap <= 1) {
        // Docked panel: in from its edge, by its own size
        return {
            away: { value1: edge.dx * window.width, value2: edge.dy * window.height },
            open: panelOpen, close: panelClose, fade: false,
        };
    }
    const dir = isLeavesWindow(window) ? { dx: 0, dy: -1 } : edge;
    return {
        away: { value1: dir.dx * shift, value2: dir.dy * shift },
        open: popupOpen, close: popupClose, fade: true,
    };
}

function stop(window) {
    for (const key of ["opening", "closing"]) {
        if (window[key]) {
            cancel(window[key]);
            delete window[key];
        }
    }
}

// Slide (and fade) for opening (from away to its place) or closing (the reverse).
// KWin's blur skips windows that are moving unless they force it, which made
// the glass go clear during the slide and snap back after; forcing it keeps
// the blur on the window (faded with it) the whole way, as Sliding popups does.
// The flags stay: they only matter while a window is moving.
function play(window, opening) {
    window.setData(Effect.WindowForceBlurRole, true);
    window.setData(Effect.WindowForceBackgroundContrastRole, true);
    const m = motion(window);
    const home = { value1: 0, value2: 0 };
    const duration = opening ? m.open : m.close;
    const animations = [animate({
        window: window,
        curve: curve,
        duration: duration,
        type: Effect.Translation,
        from: opening ? m.away : home,
        to: opening ? home : m.away,
    })];
    if (m.fade) {
        animations.push(animate({
            window: window,
            curve: curve,
            duration: duration,
            type: Effect.Opacity,
            from: opening ? 0 : 1,
            to: opening ? 1 : 0,
        }));
    }
    return animations;
}

effects.windowAdded.connect(window => {
    if (effects.hasActiveFullScreenEffect || !isAnimated(window))
        return;
    if (!effect.grab(window, Effect.WindowAddedGrabRole, true))
        return;
    stop(window);
    window.opening = play(window, true);
});

effects.windowClosed.connect(window => {
    if (effects.hasActiveFullScreenEffect || !isAnimated(window) || window.skipsCloseAnimation)
        return;
    if (!effect.grab(window, Effect.WindowClosedGrabRole, true))
        return;
    stop(window);
    window.closing = play(window, false);
});

effect.configChanged.connect(loadConfig);
loadConfig();
