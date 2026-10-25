.pragma library
// Leaves message bus between widgets. Every widget in plasmashell shares one
// QML engine, so this library has a single instance: a widget registers a
// handler under a name and others call it by name. Installed by apply.sh to
// ~/.local/share/leaves/bus.js; import it from a widget's contents/ui/ as
// "../../../../../leaves/bus.js".
//
// Each bar (the main one, and its copy while a game is fullscreen) has its own
// widgets, so handlers are tied to the window (the bar) they live in, and a
// call reaches the handler in the caller's bar.
//
// Handlers so far: "network" (tray) opens or closes the network popup; the
// argument is { expanded, anchor }, anchor being the item to open it under
// (the tray without one). If the anchor has leavesPopupOpen and
// leavesPopupHovered properties, the tray keeps them up to date while open.

var handlers = []

// windowOf: function returning the handler's window (it can change while
// loading). Returns a function that unregisters it; call it on destruction.
function register(name, windowOf, handler) {
    const entry = { name: name, windowOf: windowOf, handler: handler }
    handlers.push(entry)
    return function () { handlers = handlers.filter(h => h !== entry) }
}

function call(name, window, arg) {
    const entry = handlers.find(h => h.name === name && h.windowOf() === window)
    if (entry)
        entry.handler(arg)
    return !!entry
}

// Hover popups (HoverOpener.qml) open in a bar, one at a time
var openPopups = []

// close: function that closes it; called when another one opens in the bar.
// That happens a moment later, and only if it's still open: the tray switches
// between its own popups itself, and closing the old one in the middle of that
// switch would close the new one too.
function setPopupOpen(window, owner, open, close) {
    openPopups = openPopups.filter(p => p.owner !== owner)
    if (open) {
        openPopups.filter(p => p.window === window).forEach(p => Qt.callLater(() => {
            if (openPopups.includes(p))
                p.close()
        }))
        openPopups.push({ window: window, owner: owner, close: close })
    }
}

function popupOpen(window) {
    return openPopups.some(p => p.window === window)
}
