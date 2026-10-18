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
// Handlers so far: "network" (tray) toggles the network popup.

var handlers = []

// windowOf: function returning the handler's window (it can change while
// loading). Returns a function that unregisters it; call it on destruction.
function register(name, windowOf, handler) {
    const entry = { name: name, windowOf: windowOf, handler: handler }
    handlers.push(entry)
    return function () { handlers = handlers.filter(h => h !== entry) }
}

function call(name, window) {
    const entry = handlers.find(h => h.name === name && h.windowOf() === window)
    if (entry)
        entry.handler()
    return !!entry
}
