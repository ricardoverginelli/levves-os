// Plasma layout script: thin top bars, one per monitor.
//   main monitor:   launcher icon, window strip, perf meter (CPU, GPU usage + temp; RAM, disk usage)
//                   | weekday, date and time | media controls (only while a player is active), system tray
//   other monitors: launcher icon, window strip | weekday, date and time
// The launcher and the strip open every bar, so they sit in the same place on all of them.
// While the main monitor has a fullscreen window (e.g. a game), the second monitor's bar
// becomes a full one like the main bar's (the leaves-top-bar-follow KWin script asks).
// Re-running replaces the bars instead of adding more.
// Apply: ../apply.sh (or qdbus-qt6 org.kde.plasmashell /PlasmaShell evaluateScript "$(cat top-bar.js)")
//
// LEAVES_TARGET (prepend `const LEAVES_TARGET = "...";` to the script) picks what to do:
//   "primary"         (default) build every bar: the main one and the slim ones
//   "secondary-full"  make the second monitor's bar a full one
//   "secondary-slim"  make it a slim one again
// The secondary ones are only rebuilt when they aren't what's asked already.

const target = typeof LEAVES_TARGET !== "undefined" ? LEAVES_TARGET : "primary";
const mainRole = "leaves-top-bar";
const secondaryRole = "leaves-top-bar-secondary";
const strip = "org.leaves.windows";  // the window strip (kwin/leaves-windows' widget), when installed

function barsWith(role) {
    return panelIds.map(panelById).filter(p => {
        p.currentConfigGroup = ["Leaves"];
        return p.readConfig("role", "") == role;
    });
}

// The other monitors' bars; "full" makes the second monitor's (index 1) a full one
function setSecondary(variant, force) {
    const old = barsWith(secondaryRole);
    const current = old.length == Math.max(screenCount - 1, 0)
        && old.every(p => p.readConfig("variant", "") == variant);
    if (current && !force)
        return;
    old.forEach(p => p.remove());
    for (let screen = 1; screen < screenCount; screen++)
        buildBar(screen, secondaryRole, variant, variant == "full" && screen == 1);
}

if (target == "primary") {
    barsWith(mainRole).forEach(p => p.remove());
    buildBar(0, mainRole, "full", true);
    setSecondary("slim", true);
} else if (target == "secondary-full" || target == "secondary-slim") {
    setSecondary(target.slice("secondary-".length), false);
}

function buildBar(screen, role, variant, full) {
    function addStockClock() {
        const clock = panel.addWidget("org.kde.plasma.digitalclock");
        clock.currentConfigGroup = ["Appearance"];
        clock.writeConfig("showDate", true);
        clock.writeConfig("dateDisplayFormat", "BesideTime");
        clock.writeConfig("dateFormat", "custom");
        clock.writeConfig("customDateFormat", "ddd d MMM");
        clock.writeConfig("autoFontAndSize", false);
        clock.writeConfig("fontFamily", "Noto Sans");
        clock.writeConfig("fontSize", 9);
        clock.writeConfig("fontWeight", 600);  // SemiBold (Qt 6 weight scale)
    }

    // New panels land on whichever screen Plasma considers current, so set it:
    // screen 0 is the primary monitor, 1 the second one
    const panel = new Panel;
    panel.screen = screen;
    panel.currentConfigGroup = ["Leaves"];
    panel.writeConfig("role", role);
    panel.writeConfig("variant", variant);
    panel.location = "top";
    panel.height = 28;
    panel.floating = false;
    panel.opacity = "translucent";  // translucent + KWin blur behind it

    // Left: launcher icon, window strip, then the perf meter (full bars)
    panel.addWidget("org.leaves.launcher");
    if (knownWidgetTypes.indexOf(strip) >= 0)
        panel.addWidget(strip);
    if (full)
        panel.addWidget("org.leaves.perfmeter");

    // Center: clock, held in the middle by two flexible spacers
    const spacerLeft = panel.addWidget("org.kde.plasma.panelspacer");
    spacerLeft.currentConfigGroup = ["General"];
    spacerLeft.writeConfig("expanding", true);

    // The Leaves clock (calendar + Google agenda popup), or the stock one if it's missing
    const leavesClock = "org.leaves.clock";
    if (knownWidgetTypes.indexOf(leavesClock) >= 0)
        panel.addWidget(leavesClock);
    else
        addStockClock();

    const spacerRight = panel.addWidget("org.kde.plasma.panelspacer");
    spacerRight.currentConfigGroup = ["General"];
    spacerRight.writeConfig("expanding", true);

    if (!full)
        return;

    // Right: media controls (hidden unless something is playing), then the system
    // tray: the Leaves tray (tray/build.py) when it's installed, otherwise the
    // stock one (e.g. after a Plasma update the patches don't fit)
    panel.addWidget("org.leaves.mediabar");
    const leavesTray = "org.leaves.systemtray";
    const tray = panel.addWidget(knownWidgetTypes.indexOf(leavesTray) >= 0 ? leavesTray : "org.kde.plasma.systemtray");

    // Notifications: the Leaves ones (notifications/build.py) in place of the
    // stock ones when installed. Never both: each would show every popup. The
    // stock id stays in knownItems so the tray doesn't turn it back on.
    const leavesNotifications = "org.leaves.notifications";
    const stockNotifications = "org.kde.plasma.notifications";
    // Without the Leaves ones (e.g. a patch stopped fitting), the stock ones are turned back on.
    tray.currentConfigGroup = ["General"];
    const list = key => {
        const value = tray.readConfig(key, []);
        return (Array.isArray(value) ? value : String(value).split(",")).filter(id => id);
    };
    const others = id => id != stockNotifications && id != leavesNotifications;
    const notifications = knownWidgetTypes.indexOf(leavesNotifications) >= 0 ? leavesNotifications : stockNotifications;
    tray.writeConfig("extraItems", list("extraItems").filter(others).concat([notifications]));
    tray.writeConfig("knownItems", list("knownItems").filter(others).concat([stockNotifications, leavesNotifications]));
    tray.reloadConfig();
}
