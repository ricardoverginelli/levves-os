// Plasma layout script: thin top bar on the primary monitor.
//   left:   perf meter (CPU, GPU usage + temp; RAM, disk usage)
//   center: weekday, date and time
//   right:  system tray
// Re-running replaces the bar instead of adding a second one.
// Apply: ../apply.sh (or qdbus-qt6 org.kde.plasmashell /PlasmaShell evaluateScript "$(cat top-bar.js)")

const ROLE = "leaves-top-bar";

// Remove the bar from a previous run
for (const id of panelIds) {
    const p = panelById(id);
    p.currentConfigGroup = ["Leaves"];
    if (p.readConfig("role", "") == ROLE)
        p.remove();
}

const panel = new Panel;  // new panels go on the primary monitor
panel.currentConfigGroup = ["Leaves"];
panel.writeConfig("role", ROLE);
panel.location = "top";
panel.height = 28;
panel.floating = false;
panel.opacity = "translucent";  // translucent + KWin blur behind it

// Left: perf meter (custom widget from ../widgets)
panel.addWidget("org.leaves.perfmeter");

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
