// KWin script: open Yakuake on a monitor without a fullscreen (or borderless
// fullscreen) window, e.g. a game, so it never drops down over it.
//
// Yakuake lays itself out for KWin's active monitor when it opens (it asks
// KWin for activeOutputName, then plasmashell for that monitor's usable
// area), and moving its window afterwards leaves its contents sized for the
// old monitor. So this script owns Yakuake's shortcut instead: it makes the
// target monitor the active one first (KWin's "switch to screen", which
// focuses a window there and doesn't move the mouse), then toggles Yakuake.
// A fullscreen game can pull the active monitor back before Yakuake asks, so
// it's held there until Yakuake's window appears. When Yakuake closes, focus
// goes back to the window that had it (the game). If it still opens at the
// wrong height, it's reopened once. If Yakuake is open but
// another window has focus, the shortcut focuses Yakuake instead of closing it.
// Meta+N adds a tab and shows Yakuake the same way.
//
// Yakuake's own shortcut must be cleared so this one can take the key.
// Install: bash install.sh in os/linux/kwin (plasma/apply.sh runs it too)

function sameRect(a, b) {
    return a.x == b.x && a.y == b.y && a.width == b.width && a.height == b.height;
}

function isOnCurrentDesktop(w) {
    return w.onAllDesktops || w.desktops.indexOf(workspace.currentDesktop) != -1;
}

function isYakuake(w) {
    return w.resourceClass == "org.kde.yakuake";
}

function outputHasFullscreen(output) {
    return workspace.windowList().some(function (w) {
        if (!w.normalWindow || w.minimized || isYakuake(w) || !isOnCurrentDesktop(w))
            return false;
        if (w.output != output)
            return false;
        return w.fullScreen || (w.noBorder && sameRect(w.frameGeometry, output.geometry));
    });
}

// Main monitor = the largest one (output priority isn't exposed to scripts).
function mainOutput() {
    return workspace.screens.reduce(function (a, b) {
        return b.geometry.width * b.geometry.height > a.geometry.width * a.geometry.height ? b : a;
    });
}

// The main monitor, or another one if it has a fullscreen window
function targetOutput() {
    var main = mainOutput();
    if (!outputHasFullscreen(main))
        return main;
    return workspace.screens.find(function (o) { return o != main && !outputHasFullscreen(o); }) || null;
}

// The window to give focus back to when Yakuake closes; dropped if another
// window gets focus while Yakuake is open (not counting the one KWin focuses
// as Yakuake retracts)
var returnTo = null;
var retracting = false;

function switchTo(output) {
    // Two monitors: one step; more: step until it's the target
    for (var i = 0; i < workspace.screens.length && workspace.activeScreen != output; i++)
        workspace.slotSwitchToNextScreen();
}

// Until Yakuake has asked which monitor is active (it has by the time its
// window appears), a fullscreen game can pull the active monitor back: by
// taking focus again, or by moving the cursor (KWin makes the cursor's monitor
// the active one). Both are undone right away, a bounded number of times.
var holdOutput = null;
var holdBudget = 0;

function holdActiveOutput() {
    if (!holdOutput || workspace.activeScreen == holdOutput)
        return;
    if (--holdBudget < 0) {
        holdOutput = null;
        return;
    }
    switchTo(holdOutput);
}

// Yakuake shows itself at the size it measured on its previous toggle (for
// whichever monitor was active then) and only re-measures afterwards; the
// resize to the new monitor's height doesn't always stick. So once its size
// has settled, a window that doesn't fit its monitor is reopened: Yakuake has
// measured the right monitor by then, so the second open is sized correctly.
var reopenBudget = 0;
var reopening = false;
var settling = null;
var settle = new QTimer();
settle.singleShot = true;
settle.interval = 300;

// Yakuake is set to 100% height, so it should end at the monitor's bottom
// and only lose the panels' height
function fitsOutput(w) {
    var g = w.frameGeometry, o = w.output.geometry;
    return g.y + g.height <= o.y + o.height && g.height >= o.height - 100;
}

settle.timeout.connect(function () {
    var w = settling;
    settling = null;
    if (!w || fitsOutput(w) || reopenBudget <= 0)
        return;
    reopenBudget--;
    reopening = true;
    retracting = true;
    callDBus("org.kde.yakuake", "/yakuake/window", "org.kde.yakuake", "toggleWindowState");
});

function toggleYakuake() {
    // Open but unfocused: focus it instead of retracting. Yakuake's own
    // ToggleToFocus can't do this on Wayland (it has no activation token).
    var yakuake = workspace.windowList().find(isYakuake);
    if (yakuake && workspace.activeWindow != yakuake) {
        workspace.activeWindow = yakuake;
        return;
    }

    var open = !!yakuake;
    retracting = open;
    holdOutput = null;
    if (!open) {
        reopenBudget = 1;
        var target = targetOutput();
        if (target && target != workspace.activeScreen) {
            returnTo = workspace.activeWindow;
            switchTo(target);
            holdOutput = target;
            holdBudget = 50;
        }
    }
    callDBus("org.kde.yakuake", "/yakuake/window", "org.kde.yakuake", "toggleWindowState");
}

// A new tab, shown: Yakuake opened (as above) or focused if it isn't already
function newYakuakeTab() {
    callDBus("org.kde.yakuake", "/yakuake/sessions", "org.kde.yakuake", "addSession");
    var yakuake = workspace.windowList().find(isYakuake);
    if (!yakuake || workspace.activeWindow != yakuake)
        toggleYakuake();
}

registerShortcut("Toggle Yakuake", "Open/Retract Yakuake (avoiding fullscreen monitors)", "Meta+/", toggleYakuake);
registerShortcut("New Yakuake Tab", "Open Yakuake with a new tab", "Meta+N", newYakuakeTab);

workspace.cursorPosChanged.connect(holdActiveOutput);

workspace.windowAdded.connect(function (w) {
    if (!isYakuake(w))
        return;
    holdOutput = null;
    settling = w;
    settle.start();
    w.frameGeometryChanged.connect(function () {
        if (settling == w)
            settle.start();
    });
});

workspace.windowActivated.connect(function (w) {
    holdActiveOutput();
    if (returnTo && !retracting && w && !isYakuake(w) && w != returnTo && workspace.windowList().some(isYakuake))
        returnTo = null;
});

workspace.windowRemoved.connect(function (w) {
    if (!isYakuake(w))
        return;
    settle.stop();
    settling = null;
    retracting = false;
    if (reopening) {
        reopening = false;
        callDBus("org.kde.yakuake", "/yakuake/window", "org.kde.yakuake", "toggleWindowState");
        return;
    }
    if (!returnTo)
        return;
    var back = returnTo;
    returnTo = null;
    if (workspace.windowList().indexOf(back) != -1)
        workspace.activeWindow = back;
});
