// Plasma layout script: thin top bar.
//   left:   launcher icon, perf meter (CPU, GPU usage + temp; RAM, disk usage), media controls (only while a player is active)
//   center: weekday, date and time
//   right:  system tray
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
    const panel = new Panel;  // new panels go on the primary monitor (screen 0)
    if (target == "secondary")
        panel.screen = 1;
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

    const spacerRight = panel.addWidget("org.kde.plasma.panelspacer");
    spacerRight.currentConfigGroup = ["General"];
    spacerRight.writeConfig("expanding", true);

    // Right: system tray
    panel.addWidget("org.kde.plasma.systemtray");
}
