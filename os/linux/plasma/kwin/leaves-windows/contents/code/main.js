// KWin script: window layouts per monitor, and windows kept off a game.
//
// Layouts: Meta+M then Meta+1/2/3 (Meta held) splits the focused window's
// monitor into 1, 2 or 3 columns (1 = no layout, windows float as usual).
// KWin doesn't match multi-key sequences on Wayland, so Meta+M arms Meta+1/2/3
// for a moment instead; on their own they do nothing. The columns are
// KWin's own tiles, with no gaps, so their borders can be dragged to resize.
// The most recently used windows hold the columns:
//   - applying a layout fills them from the left with the most recent windows
//     (kept in their left-to-right order);
//   - a new window takes an empty column, or else the least recently used one's;
//   - a background window that gets focus (picked from Alt+Tab or the bar)
//     takes the column it overlaps most;
//   - a column whose window closes, is minimized or leaves the monitor goes to
//     the most recent background window.
// The windows that lose their column stay behind, untiled. A maximized or
// fullscreen window keeps its column and goes back into it afterwards; one
// dragged out of its column floats until it's put back in a tile (or the
// layout is applied again). Windows narrower than their minimum width float.
//
//   ┌─────────┬─────────┬─────────┐
//   │ 3rd     │ 1st     │ 2nd     │  columns: the 3 most recent windows
//   │ recent  │ recent  │ recent  │  (the others wait behind them)
//   └─────────┴─────────┴─────────┘
//
// A monitor's layout is the tile layout KWin saves for it in kwinrc. Ours are
// marked by a padding of 0 (KWin's default is 4), so a layout made in KWin's
// own tile editor (Meta+T) isn't taken for one of ours, and ours survive a
// re-login without a config of their own.
//
// Games: while a game is fullscreen (or borderless fullscreen) on the main
// monitor, the other windows there move to the second monitor, and windows
// opened meanwhile land there too. Nothing moves back afterwards.
// A game is a Steam (steam_app_*), Wine/Proton (.exe) or gamescope window, or
// one listed in lists.json, which also lists windows never touched here.
//
// Not tiled or moved: dialogs, Yakuake, picture-in-picture, always-on-top and
// skip-taskbar windows, games, minimized windows and lists.json's exceptions.
//
// Install: plasma/apply.sh (build.py fills LISTS below from lists.json)

const LISTS = /*LISTS*/{"games": [], "exceptions": []};
const RECONCILE_MS = 50;     // let a burst of window events settle first
const GAME_DEBOUNCE_MS = 300;  // games switch modes in several steps
const KWIN_PADDING = 4;      // KWin's default tile padding (= not one of our layouts)
const MAX_COLUMNS = 3;
const ARM_MS = 1500;         // Meta+M to Meta+1/2/3

// ── Windows ───────────────────────────────────────────────────────────────

function sameRect(a, b) {
    return a.x == b.x && a.y == b.y && a.width == b.width && a.height == b.height;
}

function isOnCurrentDesktop(w) {
    return w.onAllDesktops || w.desktops.indexOf(workspace.currentDesktop) != -1;
}

function key(w) {
    return w.internalId.toString();
}

function listed(w, list) {
    const names = [w.resourceClass, w.resourceName, w.desktopFileName].map(n => (n || "").toLowerCase());
    return list.some(entry => names.indexOf(entry) != -1);
}

function isGame(w) {
    if (!w.normalWindow)
        return false;
    const cls = (w.resourceClass || "").toLowerCase(), name = (w.resourceName || "").toLowerCase();
    return cls.startsWith("steam_app_") || cls.endsWith(".exe") || name.endsWith(".exe")
        || cls == "gamescope" || listed(w, LISTS.games);
}

function coversOutput(w) {
    return w.fullScreen || (w.noBorder && sameRect(w.frameGeometry, w.output.geometry));
}

// Windows that can hold a column (and move off a game's monitor)
function isTileable(w) {
    return w.normalWindow && !w.deleted && !w.transient && !w.skipTaskbar && !w.specialWindow
        && !w.keepAbove && w.moveable && w.resizeable
        && w.resourceClass != "org.kde.yakuake"
        && !/picture.in.picture/i.test(w.caption)
        && !isGame(w) && !listed(w, LISTS.exceptions);
}

// Most recently used first; KWin's stacking order (top first) to start with
let mru = workspace.stackingOrder.slice().reverse();

function recency(w) {
    const i = mru.indexOf(w);
    return i == -1 ? mru.length : i;
}

function byRecency(a, b) {
    return recency(a) - recency(b);
}

function workArea(output) {
    return workspace.clientArea(KWin.MaximizeArea, output, workspace.currentDesktop);
}

function overlap(a, b) {
    const w = Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x);
    const h = Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y);
    return w > 0 && h > 0 ? w * h : 0;
}

// ── Monitors ──────────────────────────────────────────────────────────────

// Main monitor = the largest one (output priority isn't exposed to scripts)
function area(o) {
    return o.geometry.width * o.geometry.height;
}

function mainOutput() {
    return workspace.screens.reduce((a, b) => area(b) > area(a) ? b : a);
}

// Where windows go to make room for a game: the largest of the others
function secondOutput() {
    const main = mainOutput();
    const others = workspace.screens.filter(o => o != main);
    return others.length ? others.reduce((a, b) => area(b) > area(a) ? b : a) : null;
}

// ── Layouts ───────────────────────────────────────────────────────────────

function rootTile(output) {
    return workspace.rootTile(output, workspace.currentDesktop);
}

// The monitor's columns if it has one of our layouts, else []
function columns(output) {
    const root = rootTile(output);
    const tiles = root.tiles;
    if (root.padding != 0 || root.layoutDirection != 1 || tiles.length < 2 || tiles.length > MAX_COLUMNS)
        return [];
    if (tiles.some(t => t.tiles.length > 0))
        return [];
    return tiles.slice().sort((a, b) => a.relativeGeometry.x - b.relativeGeometry.x);
}

// Per monitor (by name): the window holding each column, or null
const slots = {};
// Windows dragged out of a column: they float until tiled again
const floating = {};
// Windows just un-maximized or out of fullscreen: back into their column
const returning = {};
// Windows asking for a column, in order: {window, kind: "new" | "pick"}
let claims = [];

function slotsFor(output, count) {
    let s = slots[output.name];
    if (!s || s.length != count)
        s = slots[output.name] = new Array(count).fill(null);
    return s;
}

function fits(w, tile) {
    return w.minSize.width <= tile.absoluteGeometry.width;
}

function candidates(output) {
    return workspace.windowList().filter(w => isTileable(w) && w.output == output
                                         && isOnCurrentDesktop(w) && !w.minimized);
}

// A column's window away from its tile for a moment: it keeps the column
function parked(w) {
    return w.maximizeMode != 0 || w.fullScreen;
}

function untile(w) {
    if (w.tile)
        w.tile = null;
}

// Put each column's window into its tile, and nothing else
function commit(output, tiles, s) {
    s.forEach((w, i) => {
        tiles[i].windows.forEach(x => { if (x != w) untile(x); });
        if (w && w.tile != tiles[i] && !parked(w))
            w.tile = tiles[i];
    });
}

function reconcile(output) {
    const tiles = columns(output);
    if (!tiles.length) {
        delete slots[output.name];
        claims = claims.filter(c => c.window.output != output);
        return;
    }
    const s = slotsFor(output, tiles.length);
    const here = candidates(output);

    // Columns whose window is gone, minimized, moved away or dragged out
    s.forEach((w, i) => {
        if (!w)
            return;
        if (here.indexOf(w) == -1 || floating[key(w)]) {
            s[i] = null;
            return;
        }
        if (w.tile == tiles[i] || parked(w))
            return;
        if (returning[key(w)] && !w.move) {
            delete returning[key(w)];
            return;  // commit puts it back
        }
        delete returning[key(w)];
        const j = tiles.indexOf(w.tile);
        if (j != -1 && j != i) {
            // Put into another column by hand (Shift+drag): swap with its window
            s[i] = s[j];
            s[j] = w;
        } else {
            // Dragged out, or snapped with quick tiling: it floats
            floating[key(w)] = true;
            s[i] = null;
        }
    });

    // A window put into a column by hand (Shift+drag) takes it
    tiles.forEach((t, j) => {
        t.windows.forEach(w => {
            if (s.indexOf(w) != -1 || here.indexOf(w) == -1)
                return;
            delete floating[key(w)];
            if (s[j])
                untile(s[j]);
            s[j] = w;
        });
    });

    // New and picked windows take a column
    claims.filter(c => c.window.output == output).forEach(c => {
        const w = c.window;
        if (s.indexOf(w) != -1 || here.indexOf(w) == -1 || floating[key(w)])
            return;
        let i = s.indexOf(null);
        if (i == -1) {
            const leastRecent = s.slice().sort(byRecency)[s.length - 1];
            i = s.indexOf(leastRecent);
            if (c.kind == "pick") {
                const g = w.frameGeometry;
                let best = 0;
                tiles.forEach((t, j) => {
                    const o = overlap(g, t.absoluteGeometry);
                    if (o > best) {
                        best = o;
                        i = j;
                    }
                });
            }
        }
        if (!fits(w, tiles[i]))
            return;
        if (s[i])
            untile(s[i]);
        s[i] = w;
    });
    claims = claims.filter(c => c.window.output != output);

    // Empty columns go to the most recent windows behind
    s.forEach((w, i) => {
        if (w)
            return;
        const next = here.filter(x => s.indexOf(x) == -1 && !floating[key(x)] && fits(x, tiles[i]))
                         .sort(byRecency)[0];
        if (next)
            s[i] = next;
    });

    commit(output, tiles, s);
}

function reconcileAll() {
    workspace.screens.forEach(reconcile);
}

// Split the monitor into `count` equal columns (1 = no layout) and fill them
// with its most recent windows, keeping their left-to-right order
function applyLayout(output, count) {
    const root = rootTile(output);
    const old = slots[output.name] || [];
    old.forEach(w => { if (w) untile(w); });
    delete slots[output.name];
    while (root.tiles.length)
        root.tiles[root.tiles.length - 1].remove();
    candidates(output).forEach(w => delete floating[key(w)]);

    if (count < 2) {
        root.padding = KWIN_PADDING;
        return;
    }
    root.split(1);  // horizontal
    if (count == 3)
        root.tiles[1].split(1);
    root.padding = 0;
    for (let i = 0; i < count - 1; i++)
        root.tiles[i].relativeGeometry = {x: i / count, y: 0, width: 1 / count, height: 1};

    const tiles = columns(output);
    const s = slotsFor(output, tiles.length);
    const chosen = [];
    candidates(output).sort(byRecency).forEach(w => {
        if (chosen.length < tiles.length && fits(w, tiles[chosen.length]))
            chosen.push(w);
    });
    chosen.sort((a, b) => (a.frameGeometry.x + a.frameGeometry.width / 2) - (b.frameGeometry.x + b.frameGeometry.width / 2));
    chosen.forEach((w, i) => {
        if (w.maximizeMode != 0)
            w.setMaximize(false, false);
        s[i] = w;
    });
    commit(output, tiles, s);
}

let armedUntil = 0;

function layoutShortcut(count) {
    return function () {
        if (Date.now() > armedUntil)
            return;
        armedUntil = 0;
        const w = workspace.activeWindow;
        applyLayout(w ? w.output : workspace.activeScreen, count);
    };
}

// ── Games ─────────────────────────────────────────────────────────────────

function gameOnMain() {
    const main = mainOutput();
    return workspace.windowList().some(w => isGame(w) && !w.minimized && isOnCurrentDesktop(w)
                                            && w.output == main && coversOutput(w));
}

let gaming = false;

// Move a window to the other monitor, shrunk to fit if it floats
function sendAway(w, target) {
    const s = slots[w.output.name];
    if (s && s.indexOf(w) != -1)
        s[s.indexOf(w)] = null;
    untile(w);
    workspace.sendClientToScreen(w, target);
    if (w.maximizeMode != 0 || w.fullScreen)
        return;
    const a = workArea(target), g = w.frameGeometry;
    const width = Math.min(g.width, a.width), height = Math.min(g.height, a.height);
    const x = Math.min(Math.max(g.x, a.x), a.x + a.width - width);
    const y = Math.min(Math.max(g.y, a.y), a.y + a.height - height);
    if (x != g.x || y != g.y || width != g.width || height != g.height)
        w.frameGeometry = {x: x, y: y, width: width, height: height};
}

// The windows that arrive take columns by recency, like a layout being applied
function clearMain() {
    const main = mainOutput(), target = secondOutput();
    if (!target)
        return;
    candidates(main).forEach(w => sendAway(w, target));
    const s = slots[target.name];
    if (s) {
        s.forEach(w => { if (w) untile(w); });
        s.fill(null);
    }
    reconcile(target);
}

function updateGame() {
    const now = workspace.screens.length > 1 && gameOnMain();
    if (now && !gaming)
        clearMain();
    gaming = now;
}

// ── Events ────────────────────────────────────────────────────────────────

const reconcileTimer = new QTimer();
reconcileTimer.singleShot = true;
reconcileTimer.interval = RECONCILE_MS;
reconcileTimer.timeout.connect(reconcileAll);

const gameTimer = new QTimer();
gameTimer.singleShot = true;
gameTimer.interval = GAME_DEBOUNCE_MS;
gameTimer.timeout.connect(updateGame);

function schedule() {
    reconcileTimer.start();
    gameTimer.start();
}

// KWin focuses a new window before announcing it, so "new" replaces a "pick"
function claim(w, kind) {
    const c = claims.find(c => c.window == w);
    if (!c)
        claims.push({window: w, kind: kind});
    else if (kind == "new")
        c.kind = kind;
}

function watch(w) {
    const back = () => {
        if (!parked(w))
            returning[key(w)] = true;
    };
    w.maximizedChanged.connect(back);
    w.fullScreenChanged.connect(back);
    [w.minimizedChanged, w.outputChanged, w.tileChanged, w.maximizedChanged, w.fullScreenChanged,
     w.desktopsChanged, w.frameGeometryChanged].forEach(signal => signal.connect(schedule));
}

workspace.windowList().forEach(watch);

workspace.windowAdded.connect(w => {
    watch(w);
    if (isTileable(w)) {
        // Opened during a game: straight to the other monitor
        if (gaming && w.output == mainOutput() && secondOutput())
            sendAway(w, secondOutput());
        claim(w, "new");
    }
    schedule();
});

workspace.windowRemoved.connect(w => {
    mru = mru.filter(x => x != w);
    claims = claims.filter(c => c.window != w);
    delete floating[key(w)];
    delete returning[key(w)];
    schedule();
});

workspace.windowActivated.connect(w => {
    if (!w)
        return;
    mru = [w].concat(mru.filter(x => x != w));
    const s = slots[w.output.name];
    if (s && s.indexOf(w) == -1 && isTileable(w))
        claim(w, "pick");
    schedule();
});

// Layout changes made outside this script (KWin's tile editor)
const watchedRoots = [];

function watchTiles(output) {
    const root = rootTile(output);
    if (watchedRoots.indexOf(root) != -1)
        return;
    watchedRoots.push(root);
    root.childTilesChanged.connect(schedule);
    root.paddingChanged.connect(schedule);
}

workspace.screens.forEach(watchTiles);
workspace.screensChanged.connect(() => {
    workspace.screens.forEach(watchTiles);
    schedule();
});
// Each virtual desktop has its own tiles
workspace.currentDesktopChanged.connect(() => {
    workspace.screens.forEach(watchTiles);
    schedule();
});

registerShortcut("Leaves Layout Arm", "Leaves: pick a layout (then Meta+1/2/3)", "Meta+M",
                 () => { armedUntil = Date.now() + ARM_MS; });
registerShortcut("Leaves Layout 1", "Leaves: no layout on this monitor (after Meta+M)", "Meta+1", layoutShortcut(1));
registerShortcut("Leaves Layout 2", "Leaves: two columns on this monitor (after Meta+M)", "Meta+2", layoutShortcut(2));
registerShortcut("Leaves Layout 3", "Leaves: three columns on this monitor (after Meta+M)", "Meta+3", layoutShortcut(3));

schedule();
