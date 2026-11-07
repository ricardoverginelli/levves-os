// KWin script: window layouts per monitor, and windows kept off a game.
//
// Layouts: Meta+M then Meta+1/2/3 (Meta held) splits the focused window's
// monitor into 1, 2 or 3 columns (1 = no layout, windows float as usual).
// KWin doesn't match multi-key sequences on Wayland, so Meta+M arms Meta+1/2/3
// for a moment instead (each layout picked renews it, and a digit just before
// the M counts, for all three pressed at once); on their own they do nothing. The columns are
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
// fullscreen window keeps its column and goes back into it afterwards.
// Dragging a column's window onto another column swaps the two (onto another
// monitor's column, that column's window goes behind); dropping it on its own
// column lets it float until it's put back (Meta+Left/Right, a Shift drag into
// a tile, or the layout applied again). Scripts can't see the Alt key, so
// floating is "drop it where it was".
//
// Keys on a monitor with a layout (without one, the old ones):
//   Meta+Left/Right        move the window one column along, swapping with the
//                          window there; a window behind goes into the edge column;
//                          from the edge column, to the monitor beside it, if any
//                          (no layout: KWin's half tiling; on Yakuake: split
//                          the terminal side by side)
//   Meta+Shift+Right/Left  span: grow the window over the next column (the other
//                          way at the monitor's edge) / give back the last one it
//                          grew into; the window it covers goes behind
//                          (no layout: the snap assist picker, kwin/leaves-snap-assist)
//   Meta+Up/Down           KWin's move to the monitor above/below; with a layout
//                          there, the window takes a column like a picked one
//                          (on Yakuake, Meta+Down closes the focused terminal)
// A maximized window goes back into its column first, and the move or span
// applies from there (no layout: KWin's half tiling un-maximizes on its own).
// Everywhere: Meta+Shift+Down un-maximizes a maximized window, and minimizes
// one that isn't (KWin's Maximize key, Meta+Shift+Up, toggles back).
// A spanned window floats over its columns and holds all of them.
// A column too narrow for its window's minimum width grows to it, taking the
// room from the others; if the minimums can't all fit, the widest one floats.
//
// Homes: Meta+H on a window in a column makes that column its app's home (again
// clears it). The app then always opens there, on that monitor (main or
// secondary), never where it was closed; it can be moved freely afterwards.
// The window in the way moves to a free column; with none free the layout
// grows by one (no layout counts as one column), and at three the rightmost
// window without a home goes behind (all homes: the least recent one). A home
// past the layout's columns is its last one. Homes need two monitors (with one,
// they're ignored) and live in this machine's kwinrc, [Script-leaves-windows]
// homes, written through plasmashell's scripting (scripts can't write config).
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
// The bar's window strip (widgets/org.leaves.windows) shows each monitor's
// layout and columns: this script writes them into the strips' "state" setting
// through plasmashell's scripting (a KWin script can't serve D-Bus), and the
// strip picks a layout with the keyless "Leaves Layout <monitor> <n>" shortcuts.
//
// Install: plasma/apply.sh (build.py fills LISTS below from lists.json)

const LISTS = /*LISTS*/{"games": [], "exceptions": []};
const RECONCILE_MS = 50;     // let a burst of window events settle first
const GAME_DEBOUNCE_MS = 300;  // games switch modes in several steps
const KWIN_PADDING = 4;      // KWin's default tile padding (= not one of our layouts)
const MAX_COLUMNS = 3;
const MIN_OTHER_COLUMN = 400;  // room a wide window leaves each other column when it claims one
const WIDEN_SLACK = 2;       // px: tile widths round, so don't chase single pixels

// Spans: the sides a window grew to, in order ("l"/"r"), so shrinking gives back the last
const growth = {};
const ARM_MS = 1500;         // Meta+M to Meta+1/2/3, renewed by each layout picked
const EARLY_MS = 400;        // a digit landing just before the M (all three pressed together)

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

// Wide enough room on the monitor: its column can grow to the window's
// minimum width (widen) and still leave the others some room
function fits(w, tiles) {
    const total = tiles.reduce((sum, t) => sum + t.absoluteGeometry.width, 0);
    return w.minSize.width <= total - (tiles.length - 1) * MIN_OTHER_COLUMN;
}

function candidates(output) {
    return workspace.windowList().filter(w => isTileable(w) && w.output == output
                                         && isOnCurrentDesktop(w) && !w.minimized);
}

// A column's window away from its tile for a moment (maximized, fullscreen
// or being dragged): it keeps the column
function parked(w) {
    return w.maximizeMode != 0 || w.fullScreen || w.move;
}

function untile(w) {
    if (w.tile)
        w.tile = null;
}

// The columns a window holds, first to last ([-1, -1] for none)
function spanOf(s, w) {
    return [s.indexOf(w), s.lastIndexOf(w)];
}

function spanned(s, w) {
    return s.indexOf(w) != s.lastIndexOf(w);
}

// Put each column's window into its tile, and nothing else; a spanned window
// floats over the union of its tiles
function commit(output, tiles, s) {
    s.forEach((w, i) => {
        tiles[i].windows.forEach(x => { if (x != w) untile(x); });
        if (!w || parked(w))
            return;
        const span = spanOf(s, w);
        if (span[0] == span[1]) {
            if (w.tile != tiles[i])
                w.tile = tiles[i];
            return;
        }
        if (i != span[0])
            return;
        untile(w);
        const a = tiles[span[0]].absoluteGeometry, b = tiles[span[1]].absoluteGeometry;
        const g = {x: a.x, y: a.y, width: b.x + b.width - a.x, height: a.height};
        if (!sameRect(w.frameGeometry, g))
            w.frameGeometry = g;
    });
}

// Grow columns narrower than their window's minimum width, taking the room
// from the others in proportion to what they have above their own minimum.
// Columns resized wider by hand stay as they are.
function widen(tiles, s) {
    const total = tiles.reduce((sum, t) => sum + t.absoluteGeometry.width, 0);
    const need = s.map(w => w && !parked(w) && !spanned(s, w) ? w.minSize.width : 0);
    const sum = list => list.reduce((a, b) => a + b, 0);
    // The minimums don't all fit: the widest window floats
    while (sum(need) > total) {
        const i = need.indexOf(Math.max.apply(null, need));
        floating[key(s[i])] = true;
        untile(s[i]);
        s[i] = null;
        need[i] = 0;
    }
    const widths = tiles.map(t => t.absoluteGeometry.width);
    let deficit = 0;
    widths.forEach((width, i) => {
        if (width < need[i] - WIDEN_SLACK) {
            deficit += need[i] + WIDEN_SLACK - width;
            widths[i] = need[i] + WIDEN_SLACK;
        }
    });
    if (!deficit)
        return;
    const room = widths.map((width, i) => Math.max(width - need[i] - WIDEN_SLACK, 0));
    const totalRoom = sum(room);
    if (totalRoom <= 0)
        return;
    widths.forEach((width, i) => widths[i] = width - deficit * room[i] / totalRoom);
    let x = 0;
    for (let i = 0; i < tiles.length - 1; i++) {
        tiles[i].relativeGeometry = {x: x / total, y: 0, width: widths[i] / total, height: 1};
        x += widths[i];
    }
}

// A new window of an app whose home is this monitor
function homeClaim(c, output) {
    if (c.kind != "new" || c.window.output != output)
        return null;
    const h = homeOf(c.window);
    return h && h.output == output ? h : null;
}

function reconcile(output) {
    let tiles = columns(output);
    // No layout counts as one column: a home app opening here makes it two
    if (!tiles.length && rootTile(output).tiles.length == 0 && claims.some(c => homeClaim(c, output))) {
        resplit(output, 2);
        tiles = columns(output);
    }
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
        if (spanned(s, w) && !parked(w)) {
            const j = tiles.indexOf(w.tile);
            if (j != -1) {
                // Shift-dragged into one of the tiles: that column only
                s.forEach((x, k) => { if (x == w && k != j) s[k] = null; });
                s[j] = w;
            } else if (w.tile) {
                floating[key(w)] = true;  // snapped some other way
                s.forEach((x, k) => { if (x == w) s[k] = null; });
            }
            delete returning[key(w)];
            return;
        }
        if (w.tile == tiles[i] || parked(w))
            return;
        if (returning[key(w)]) {
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
        const home = homeClaim(c, output);
        if (home && here.indexOf(w) != -1) {
            delete floating[key(w)];
            tiles = placeHome(output, tiles, s, w, home.column);
            return;
        }
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
        if (!fits(w, tiles))
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
        const next = here.filter(x => s.indexOf(x) == -1 && !floating[key(x)] && fits(x, tiles))
                         .sort(byRecency)[0];
        if (next)
            s[i] = next;
    });

    widen(tiles, s);
    commit(output, tiles, s);
}

function reconcileAll() {
    workspace.screens.forEach(reconcile);
    // Forget how windows grew once they no longer span
    Object.keys(growth).forEach(k => {
        if (!Object.keys(slots).some(o => slots[o].some(w => w && key(w) == k && spanned(slots[o], w))))
            delete growth[k];
    });
}

// Split the monitor into `count` equal columns (1 = no layout) and fill them
// with its most recent windows, keeping their left-to-right order
function applyLayout(output, count) {
    const old = slots[output.name] || [];
    old.forEach(w => { if (w) untile(w); });
    delete slots[output.name];
    candidates(output).forEach(w => delete floating[key(w)]);
    if (!resplit(output, count))
        return;

    const tiles = columns(output);
    const s = slotsFor(output, tiles.length);
    const chosen = [];
    candidates(output).sort(byRecency).forEach(w => {
        if (chosen.length < tiles.length && fits(w, tiles))
            chosen.push(w);
    });
    chosen.sort((a, b) => (a.frameGeometry.x + a.frameGeometry.width / 2) - (b.frameGeometry.x + b.frameGeometry.width / 2));
    chosen.forEach((w, i) => {
        if (w.maximizeMode != 0)
            w.setMaximize(false, false);
        s[i] = w;
    });
    widen(tiles, s);
    commit(output, tiles, s);
}

// The monitor's tiles as `count` equal columns (1 = none); false for none
function resplit(output, count) {
    const root = rootTile(output);
    while (root.tiles.length)
        root.tiles[root.tiles.length - 1].remove();
    if (count < 2) {
        root.padding = KWIN_PADDING;
        return false;
    }
    root.split(1);  // horizontal
    if (count == 3)
        root.tiles[1].split(1);
    root.padding = 0;
    for (let i = 0; i < count - 1; i++)
        root.tiles[i].relativeGeometry = {x: i / count, y: 0, width: 1 / count, height: 1};
    return true;
}

// One more column on the right, the others keeping their windows; the new
// tiles (s grows in place)
function grow(output, s) {
    s.forEach(w => { if (w) untile(w); });
    resplit(output, s.length + 1);
    s.push(null);
    return columns(output);
}

// A new window of an app with a home here takes its home column; the window
// in the way moves to a free column, one grown for it, or (at three) into the
// column of the rightmost window without a home, which goes behind. Returns
// the tiles (new ones if the layout grew).
function placeHome(output, tiles, s, w, column) {
    s.forEach((x, k) => { if (x == w) s[k] = null; });
    if (w.maximizeMode != 0)
        w.setMaximize(false, false);  // apps reopening maximized: into the column all the same
    const i = Math.min(column, s.length - 1);
    const occ = s[i];
    s[i] = w;
    if (!occ)
        return tiles;
    s.forEach((x, k) => { if (x == occ) s[k] = null; });  // a spanned one gives its columns back
    let f = s.findIndex(x => !x);
    if (f == -1 && s.length < MAX_COLUMNS) {
        tiles = grow(output, s);
        f = s.length - 1;
    }
    if (f != -1) {
        s[f] = occ;
        return tiles;
    }
    // Full: the rightmost window without a home goes behind (all homes: the least recent)
    const held = s.map((x, k) => ({w: k == i ? occ : x, k: k}));
    const loose = held.filter(x => !hasHome(x.w));
    const out = loose.length ? loose[loose.length - 1] : held.slice().sort((a, b) => byRecency(b.w, a.w))[0];
    untile(out.w);
    if (out.w != occ)
        s[out.k] = occ;
    return tiles;
}

let armedUntil = 0;
let early = null;  // {count, at}: a digit pressed before Meta+M

function applyToFocused(count) {
    const w = workspace.activeWindow;
    applyLayout(w ? w.output : workspace.activeScreen, count);
    schedule();
}

function arm() {
    armedUntil = Date.now() + ARM_MS;
    if (early && Date.now() - early.at < EARLY_MS)
        applyToFocused(early.count);
    early = null;
}

// ── Homes ─────────────────────────────────────────────────────────────────

// {app: {role: "main" | "secondary", column: 0-based}}
let homes = {};
try {
    homes = JSON.parse(readConfig("homes", "{}")) || {};
} catch (e) {
    homes = {};
}

function appId(w) {
    return (w.desktopFileName || w.resourceClass || "").toLowerCase();
}

function hasHome(w) {
    return !!w && !!homes[appId(w)];
}

// The window's home: {output, column}, or null (none, or only one monitor)
function homeOf(w) {
    const h = homes[appId(w)];
    if (!h || workspace.screens.length < 2)
        return null;
    const output = h.role == "main" ? mainOutput() : secondOutput();
    return output ? {output: output, column: h.column} : null;
}

function saveHomes() {
    const script = 'const c = ConfigFile("kwinrc", "Script-leaves-windows"); c.writeEntry("homes", HOMES);';
    callDBus("org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript",
             script.replace("HOMES", JSON.stringify(JSON.stringify(homes))));
}

function osd(text) {
    callDBus("org.kde.plasmashell", "/org/kde/osdService", "org.kde.osdService", "showText", "go-home", text);
}

// Meta+H: the focused window's column becomes its app's home; again clears it
function toggleHome() {
    const w = workspace.activeWindow;
    if (!w || !isTileable(w))
        return;
    const id = appId(w);
    const name = id.split(".").pop();
    if (workspace.screens.length < 2) {
        osd("Homes need two monitors");
        return;
    }
    const role = w.output == mainOutput() ? "main" : "secondary";
    const s = slots[w.output.name];
    const i = s ? s.indexOf(w) : -1;
    const h = homes[id];
    if (h && (i == -1 || (h.role == role && h.column == i))) {
        delete homes[id];
        saveHomes();
        osd(name + ": no home");
        return;
    }
    if (i == -1) {
        osd("Put " + name + " in a column first");
        return;
    }
    homes[id] = {role: role, column: i};
    saveHomes();
    osd(name + " opens here (" + role + ", column " + (i + 1) + ")");
}

// ── The bar's window strip ────────────────────────────────────────────────

function uuid(w) {
    return w.internalId.toString().replace(/[{}]/g, "").toLowerCase();
}

const STRIP_SCRIPT = 'for (const p of panels()) for (const w of p.widgets()) if (w.type == "org.leaves.windows") {'
    + ' w.currentConfigGroup = ["General"]; w.writeConfig("state", STATE); w.reloadConfig(); }';
let published = null;

// {monitor name: {columns: n, windows: [uuid or null per column]}}
function publish() {
    const state = {};
    workspace.screens.forEach(o => {
        const s = slots[o.name];
        state[o.name] = {columns: s ? s.length : 1, windows: s ? s.map(w => w ? uuid(w) : null) : []};
    });
    const json = JSON.stringify(state);
    if (json == published)
        return;
    published = json;
    callDBus("org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript",
             STRIP_SCRIPT.replace("STATE", JSON.stringify(json)));
}

// The strip's layout picker: one keyless shortcut per monitor and layout
const stripShortcuts = [];

function registerStripShortcuts() {
    workspace.screens.forEach(o => {
        const name = o.name;
        if (stripShortcuts.indexOf(name) != -1)
            return;
        stripShortcuts.push(name);
        for (let n = 1; n <= MAX_COLUMNS; n++) {
            const count = n;
            registerShortcut("Leaves Layout " + name + " " + count,
                             "Leaves: " + count + " column(s) on " + name + " (the bar's layout picker)", "", () => {
                const output = workspace.screens.find(x => x.name == name);
                if (output) {
                    applyLayout(output, count);
                    schedule();
                }
            });
        }
    });
}

// Held Meta+M stays armed: switching between 2 and 3 needs no new M
function layoutShortcut(count) {
    return function () {
        if (Date.now() > armedUntil) {
            early = {count: count, at: Date.now()};
            return;
        }
        armedUntil = Date.now() + ARM_MS;
        applyToFocused(count);
    };
}

// ── Moving and spanning with the keys ─────────────────────────────────────

// The focused window and its monitor's columns, if that monitor has a layout
function focusedInLayout() {
    const w = workspace.activeWindow;
    if (!w || !isTileable(w) || w.minimized)
        return null;
    const tiles = columns(w.output);
    if (!tiles.length)
        return null;
    reconcile(w.output);  // up to date before rearranging
    return {w: w, tiles: tiles, s: slotsFor(w.output, tiles.length)};
}

// Runs of columns held by the same window (an empty column is a run of its own)
function blocks(s) {
    const out = [];
    s.forEach(w => {
        const last = out[out.length - 1];
        if (w && last && last.w == w)
            last.n++;
        else
            out.push({w: w, n: 1});
    });
    return out;
}

// A maximized window keeps its columns, so the keys rearrange them out of sight:
// it comes back into them (watch() marks it returning)
function unmaximize(w) {
    if (w.maximizeMode != 0)
        w.setMaximize(false, false);
}

// Meta+Shift+Down: a maximized window back to its size (its column, with a
// layout), any other one minimized
function restoreOrMinimize() {
    const w = workspace.activeWindow;
    if (!w)
        return;
    if (w.maximizeMode != 0)
        unmaximize(w);
    else if (w.minimizable)
        w.minimized = true;
}

// Yakuake: Meta+Left/Right split its terminal side by side instead (tiling the
// drop-down breaks it)
function splitYakuake() {
    callDBus("org.kde.yakuake", "/yakuake/sessions", "org.kde.yakuake", "activeTerminalId",
             id => callDBus("org.kde.yakuake", "/yakuake/sessions", "org.kde.yakuake",
                            "splitTerminalLeftRight", id));
}

function closeYakuakeTerminal() {
    callDBus("org.kde.yakuake", "/yakuake/sessions", "org.kde.yakuake", "activeTerminalId",
             id => callDBus("org.kde.yakuake", "/yakuake/sessions", "org.kde.yakuake",
                            "removeTerminal", id));
}

function yakuakeFocused() {
    const w = workspace.activeWindow;
    return w && w.resourceClass == "org.kde.yakuake";
}

// Meta+Down: KWin's move one screen down (its key is ours, apply.sh), but
// Yakuake closes its terminal instead
function down() {
    if (yakuakeFocused())
        closeYakuakeTerminal();
    else
        callDBus("org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component", "invokeShortcut",
                 "Window One Screen Down");
}

// The monitor directly left or right of this one, sharing some height with it
function outputBeside(output, side) {
    const g = output.geometry;
    return workspace.screens.find(o => {
        const h = o.geometry;
        if (o == output || h.y >= g.y + g.height || g.y >= h.y + h.height)
            return false;
        return side == "left" ? h.x + h.width <= g.x : h.x >= g.x + g.width;
    });
}

// Meta+Left/Right: the window's columns trade places with the next run along;
// from the edge column, to the monitor beside it (if there's one that way)
function moveWindow(side) {
    if (yakuakeFocused()) {
        splitYakuake();
        return;
    }
    const c = focusedInLayout();
    if (!c) {
        if (side == "left")
            workspace.slotWindowQuickTileLeft();
        else
            workspace.slotWindowQuickTileRight();
        return;
    }
    const w = c.w, s = c.s;
    delete floating[key(w)];
    if (s.indexOf(w) == -1) {
        // From behind (or floating): into the edge column
        const i = side == "left" ? 0 : s.length - 1;
        const other = s[i];
        if (other && !spanned(s, other))
            untile(other);
        s[i] = w;
    } else {
        const bs = blocks(s);
        const b = bs.findIndex(x => x.w == w);
        const t = side == "left" ? b - 1 : b + 1;
        if ((t < 0 || t >= bs.length) && outputBeside(w.output, side)) {
            // At the edge with a monitor beside it: over there, as KWin does without
            // a layout (watch() gives it a column there, and this one refills)
            callDBus("org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component",
                     "invokeShortcut", side == "left" ? "Window One Screen to the Left"
                                                      : "Window One Screen to the Right");
            return;
        }
        if (t >= 0 && t < bs.length) {  // at the edge: only un-maximized
            const moved = bs[b];
            bs[b] = bs[t];
            bs[t] = moved;
            let k = 0;
            bs.forEach(x => { for (let n = 0; n < x.n; n++) s[k++] = x.w; });
        }
    }
    commit(w.output, c.tiles, s);
    unmaximize(w);
    schedule();
}

// Meta+Shift+Right grows the window over the next column (the one before it at
// the monitor's edge); Meta+Shift+Left gives back the last column it grew into
function spanWindow(side) {
    const c = focusedInLayout();
    if (!c) {
        callDBus("org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component", "invokeShortcut",
                 side == "left" ? "Leaves Snap Assist Left" : "Leaves Snap Assist Right");
        return;
    }
    const w = c.w, s = c.s;
    if (s.indexOf(w) != -1)
        spanSlots(w, s, side);
    commit(w.output, c.tiles, s);
    unmaximize(w);
    schedule();  // a column given back goes to the most recent window behind
}

// One span key's change to the columns (none across the whole monitor / in one column)
function spanSlots(w, s, side) {
    const span = spanOf(s, w);
    const grown = growth[key(w)] || (growth[key(w)] = []);
    if (side == "right") {
        let t, dir;
        if (span[1] + 1 < s.length) {
            t = span[1] + 1;
            dir = "r";
        } else if (span[0] > 0) {
            t = span[0] - 1;
            dir = "l";
        } else {
            return;  // already across the whole monitor
        }
        const other = s[t];
        if (other && !spanned(s, other))
            untile(other);
        s[t] = w;
        grown.push(dir);
    } else {
        if (!spanned(s, w))
            return;
        const dir = grown.pop() || "r";
        s[dir == "r" ? span[1] : span[0]] = null;
    }
}

// ── Games ─────────────────────────────────────────────────────────────────

function gameOnMain() {
    const main = mainOutput();
    return workspace.windowList().some(w => isGame(w) && !w.minimized && isOnCurrentDesktop(w)
                                            && w.output == main && coversOutput(w));
}

let gaming = false;

// Move a window to the other monitor, shrunk to fit if it floats
let sending = false;  // windows moved for a game join their new monitor by recency, not as picks

function sendAway(w, target) {
    const s = slots[w.output.name];
    if (s)
        s.forEach((x, k) => { if (x == w) s[k] = null; });
    untile(w);
    sending = true;
    workspace.sendClientToScreen(w, target);
    sending = false;
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
reconcileTimer.timeout.connect(() => {
    reconcileAll();
    publish();
});

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

// ── Dragging a column's window ────────────────────────────────────────────

// The column a window being dragged came from: {output (name), index}
const dragFrom = {};

function contains(r, p) {
    return p.x >= r.x && p.x < r.x + r.width && p.y >= r.y && p.y < r.y + r.height;
}

function dragStarted(w) {
    const s = slots[w.output.name];
    if (s && s.indexOf(w) != -1)
        dragFrom[key(w)] = {output: w.output.name, index: s.indexOf(w), moving: w.move};
}

// The window's columns on the monitor it was dragged from go to `other` (its
// first column) or empty
function release(old, w, index, other) {
    if (!old)
        return;
    old.forEach((x, k) => { if (x == w) old[k] = k == index ? other : null; });
}

// Dropped on another column: the two swap (on another monitor's column, that
// column's window goes behind). Dropped on its own column: it floats. A resize
// (still in its tile) changes nothing.
function dragFinished(w) {
    const from = dragFrom[key(w)];
    delete dragFrom[key(w)];
    if (!from)
        return;
    const old = slots[from.output];
    const sameOutput = w.output.name == from.output;
    const tiles = columns(w.output);
    const s = slots[w.output.name];
    if (!from.moving || (sameOutput && w.tile && tiles.indexOf(w.tile) == from.index)) {
        schedule();  // a resize, or put back: commit restores a span's geometry
        return;
    }
    const p = workspace.cursorPos;
    const j = tiles.findIndex(t => contains(t.absoluteGeometry, p));
    if (!s || j == -1 || (sameOutput && j == from.index)) {
        release(old, w, from.index, null);
        untile(w);
        floating[key(w)] = true;
        schedule();
        return;
    }
    const other = s[j];
    delete floating[key(w)];
    release(old, w, from.index, sameOutput ? other : null);
    if (!sameOutput && other)
        untile(other);
    if (other && spanned(s, other))
        s.forEach((x, k) => { if (x == other && k != from.index) s[k] = null; });
    s[j] = w;
    // Tiled right away: the next reconcile would take an untiled one for dragged out
    w.tile = tiles[j];
    if (sameOutput && other)
        other.tile = tiles[from.index];
    schedule();
}

function watch(w) {
    w.interactiveMoveResizeStarted.connect(() => dragStarted(w));
    w.interactiveMoveResizeFinished.connect(() => dragFinished(w));
    const back = () => {
        if (!parked(w))
            returning[key(w)] = true;
    };
    w.maximizedChanged.connect(back);
    w.fullScreenChanged.connect(back);
    // Moved to another monitor (Meta+Up/Down): it takes a column there like a picked window
    w.outputChanged.connect(() => {
        if (!sending && !w.move && isTileable(w))
            claim(w, "pick");
    });
    [w.minimizedChanged, w.outputChanged, w.tileChanged, w.maximizedChanged, w.fullScreenChanged,
     w.desktopsChanged, w.frameGeometryChanged].forEach(signal => signal.connect(schedule));
}

workspace.windowList().forEach(watch);

workspace.windowAdded.connect(w => {
    watch(w);
    if (isTileable(w)) {
        // Opened during a game: straight to the other monitor
        const home = homeOf(w);
        if (gaming && w.output == mainOutput() && secondOutput())
            sendAway(w, secondOutput());
        else if (home && home.output != w.output && !(gaming && home.output == mainOutput()))
            sendAway(w, home.output);
        claim(w, "new");
    }
    schedule();
});

workspace.windowRemoved.connect(w => {
    mru = mru.filter(x => x != w);
    claims = claims.filter(c => c.window != w);
    delete floating[key(w)];
    delete returning[key(w)];
    delete dragFrom[key(w)];
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
    registerStripShortcuts();
    schedule();
});
// Each virtual desktop has its own tiles
workspace.currentDesktopChanged.connect(() => {
    workspace.screens.forEach(watchTiles);
    schedule();
});

registerShortcut("Leaves Layout Arm", "Leaves: pick a layout (then Meta+1/2/3)", "Meta+M",
                 arm);
registerShortcut("Leaves Layout 1", "Leaves: no layout on this monitor (after Meta+M)", "Meta+1", layoutShortcut(1));
registerShortcut("Leaves Layout 2", "Leaves: two columns on this monitor (after Meta+M)", "Meta+2", layoutShortcut(2));
registerShortcut("Leaves Layout 3", "Leaves: three columns on this monitor (after Meta+M)", "Meta+3", layoutShortcut(3));
registerShortcut("Leaves Move Left", "Leaves: move the window a column left (no layout: tile left)",
                 "Meta+Left", () => moveWindow("left"));
registerShortcut("Leaves Move Right", "Leaves: move the window a column right (no layout: tile right)",
                 "Meta+Right", () => moveWindow("right"));
registerShortcut("Leaves Down", "Leaves: move the window a monitor down (Yakuake: close the terminal)",
                 "Meta+Down", down);
registerShortcut("Leaves Span Right", "Leaves: span the window over the next column (no layout: snap assist)",
                 "Meta+Shift+Right", () => spanWindow("right"));
registerShortcut("Leaves Span Left", "Leaves: give back the last column spanned (no layout: snap assist)",
                 "Meta+Shift+Left", () => spanWindow("left"));
registerShortcut("Leaves Restore Or Minimize", "Leaves: un-maximize the window, or minimize it if it isn't maximized",
                 "Meta+Shift+Down", restoreOrMinimize);
registerShortcut("Leaves Home", "Leaves: the window's column becomes its app's home (again: no home)",
                 "Meta+H", toggleHome);
registerStripShortcuts();

schedule();
