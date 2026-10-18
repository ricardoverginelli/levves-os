// KWin script: move Yakuake off any monitor that has a fullscreen (or
// borderless fullscreen) window, e.g. a game, so it never drops down over it.
//
// Install: cp -r yakuake-avoid-fullscreen ~/.local/share/kwin/scripts/
//   kwriteconfig6 --file kwinrc --group Plugins --key yakuake-avoid-fullscreenEnabled true
//   qdbus-qt6 org.kde.KWin /KWin reconfigure

function sameRect(a, b) {
    return a.x == b.x && a.y == b.y && a.width == b.width && a.height == b.height;
}

function isOnCurrentDesktop(w) {
    return w.onAllDesktops || w.desktops.indexOf(workspace.currentDesktop) != -1;
}

function outputHasFullscreen(output) {
    return workspace.windowList().some(function (w) {
        if (!w.normalWindow || w.minimized || w.resourceClass == "org.kde.yakuake" || !isOnCurrentDesktop(w))
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

// Yakuake reopens on whichever monitor it was last on, so always pick the
// target ourselves: the main monitor, or another one if it has a fullscreen window.
function placeYakuake(w) {
    var from = w.output;
    var main = mainOutput();
    var target = outputHasFullscreen(main)
        ? workspace.screens.find(function (o) { return o != main && !outputHasFullscreen(o); })
        : main;
    if (!from || !target || target == from)
        return;
    // Yakuake sized itself for `from`; keep the same proportions on `target`.
    var g = w.frameGeometry, src = from.geometry, dst = target.geometry;
    var width = Math.round(g.width / src.width * dst.width);
    var height = Math.round(g.height / src.height * dst.height);
    w.frameGeometry = {
        x: dst.x + Math.round((dst.width - width) / 2),
        y: dst.y + (g.y - src.y),
        width: width,
        height: height
    };
    workspace.activeWindow = w;
}

workspace.windowAdded.connect(function (w) {
    if (w.resourceClass == "org.kde.yakuake")
        placeYakuake(w);
});
