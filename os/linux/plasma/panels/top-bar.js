// Plasma layout script: thin top bar.
//   left:   launcher icon, perf meter (CPU, GPU usage + temp; RAM, disk usage), media controls (only while a player is active)
//   center: weekday, date and time
//   right:  system tray (the Leaves tray, see ../tray/)
// Re-running replaces the bar instead of adding a second one.
// Apply: ../apply.sh (or qdbus-qt6 org.kde.plasmashell /PlasmaShell evaluateScript "$(cat top-bar.js)")
//
// LEAVES_TARGET (prepend `const LEAVES_TARGET = "...";` to the script) picks what to do:
//   "primary"        (default) build the bar on the primary monitor
//   "secondary"      build a copy on the second monitor (used by the
//                    leaves-top-bar-follow KWin script while a game is fullscreen)
//   "secondary-off"  remove that copy

const target = typeof LEAVES_TARGET !== "undefined" ? LEAVES_TARGET : "primary";
const role = target == "primary" ? "leaves-top-bar" : "leaves-top-bar-secondary";

// Remove the bar from a previous run
for (const id of panelIds) {
    const p = panelById(id);
    p.currentConfigGroup = ["Leaves"];
    if (p.readConfig("role", "") == role)
        p.remove();
}

if (target != "secondary-off" && !(target == "secondary" && screenCount < 2))
    buildBar();

function buildBar() {
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
    panel.screen = target == "secondary" ? 1 : 0;
    panel.currentConfigGroup = ["Leaves"];
    panel.writeConfig("role", role);
    panel.location = "top";
    panel.height = 28;
    panel.floating = false;
    panel.opacity = "translucent";  // translucent + KWin blur behind it

    // Left: launcher icon, perf meter, then media controls (hidden unless something is playing)
    panel.addWidget("org.leaves.launcher");
    panel.addWidget("org.leaves.perfmeter");
    panel.addWidget("org.leaves.mediabar");

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

    // Right: system tray. The Leaves tray (tray/build.py) when it's installed,
    // otherwise the stock one (e.g. after a Plasma update the patches don't fit)
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
