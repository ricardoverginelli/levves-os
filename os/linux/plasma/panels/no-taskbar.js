// Plasma layout script: remove the stock taskbar (any panel holding a task
// manager or Kickoff). The Leaves top bar's launcher replaces Kickoff, and
// Alt+Tab replaces the task list.
// Apply: ../apply.sh (or qdbus-qt6 org.kde.plasmashell /PlasmaShell evaluateScript "$(cat no-taskbar.js)")

const taskbarWidgets = ["org.kde.plasma.icontasks", "org.kde.plasma.taskmanager", "org.kde.plasma.kickoff"];

for (const id of panelIds) {
    const p = panelById(id);
    if (p.widgets().some(w => taskbarWidgets.includes(w.type)))
        p.remove();
}
