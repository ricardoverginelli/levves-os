// Centered launcher. Subtle icon in the bar; Super or a click opens a window
// centered on the active screen (layer shell, no anchors).
//
//   ┌ Tasks  CPU GPU RAM Disk ┬ search ─────────────────┬ Lock ──────────┐
//   │ apps with a window      │ pinned apps (pin at end)│ Power Off      │
//   │ Background              │ ───                     │ Restart        │
//   │ tray apps, helpers      │ recent apps, newest     │ Sleep          │
//   │                         │ first — or search       │ Log Out        │
//   │                         │ results while typing,   │ ───            │
//   │                         │ grouped (Apps, Files…)  │ System Settings│
//   │                         │                         │ (user)         │
//   └─────────────────────────┴─────────────────────────┴────────────────┘
//
// Keys: focus stays in the search field; arrows move a highlight between
// areas. Down = list, Right = side panel (from search only when the cursor is
// at the end), Left = task manager (from search only when the cursor is at the
// start), Left/Right from a side area = back, Tab/Shift+Tab = next/previous
// area, Enter = run, Esc = close. Power Off, Restart and Log Out ask for a
// second Enter/click.
// Pins: Alt+Right pins, Alt+Left unpins, Alt+Up/Down reorders pinned apps
// (Ctrl+P toggles). Right-click a row (or click its pin) to pin/unpin it.
// Tasks: Enter (or a click) switches to the app's window; Alt+Left (or its ×)
// asks the app to quit, and doing it again within 5s force-quits it. Click a
// column header to sort by it (again for by name).
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.components as KirigamiComponents
import org.kde.layershell as LayerShell
import org.kde.coreaddons as KCoreAddons
import org.kde.kcmutils as KCMUtils
import org.kde.plasma.private.kicker as Kicker
import org.kde.plasma.private.sessions as Sessions
import org.kde.ksysguard.process as Process
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    // DESIGN.md motion and spacing
    readonly property var houseCurve: [0.2, 0.8, 0.2, 1, 1, 1]
    readonly property int openDuration: 200
    readonly property int closeDuration: 140
    readonly property int hoverDuration: 120
    readonly property int edgeMargin: 12   // same as the perf meter's
    readonly property int pad: 12
    readonly property int rowHeight: 36
    readonly property int twoLineRowHeight: 44
    readonly property int sideWidth: 200
    readonly property int taskWidth: 360
    readonly property int taskRowHeight: 32
    readonly property int taskCellWidth: 42
    readonly property int fadeSize: 24     // scroll hint at the list's edges

    // Pins survive the bar being rebuilt (new applet id), so the client id is fixed
    readonly property string pinsClient: "org.leaves.launcher.favorites"

    // Apps never listed in recents or search (System Settings has its own row
    // in the side panel). Pinning one still shows it.
    readonly property var hiddenApps: ["systemsettings.desktop", "org.kde.discover.desktop"]
    function isHidden(favoriteId) {
        return hiddenApps.includes(favoriteId.replace(/^applications:/, ""))
    }
    function isApp(favoriteId) {
        return favoriteId.startsWith("applications:") || favoriteId.endsWith(".desktop")
    }

    // Search group headers: KRunner's runner names, shortened
    readonly property var groupLabels: ({
        "Applications": "Apps",
        "Desktop Search": "Files",
        "File Search": "Files",
        "Recent Files": "Files",
        "System Settings": "Settings",
    })

    // Keyboard state: which area has the highlight
    property string area: "search"   // "tasks" | "search" | "list" | "side"
    property string areaBeforeSide: "search"
    property string areaBeforeTasks: "search"
    readonly property bool searching: search.text.length > 0
    readonly property var entries: searching ? searchEntries : homeEntries
    property var homeEntries: []
    property var searchEntries: []

    activationTogglesExpanded: false
    // The bar icon is the "full" representation: Plasma never creates a compact
    // one for widgets without a full one
    preferredRepresentation: fullRepresentation
    toolTipMainText: "Launcher"
    toolTipSubText: "Apps, files, power and session"

    fullRepresentation: MouseArea {
        id: barButton
        implicitWidth: root.edgeMargin + 16  // + the perf meter's own 12px edge ≈ 16px group gap
        Layout.minimumWidth: implicitWidth
        Layout.maximumWidth: implicitWidth
        Layout.fillHeight: true
        hoverEnabled: true
        onClicked: root.toggle()

        Kirigami.Icon {
            id: barIcon
            x: root.edgeMargin
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: "leaves-leaf"
            isMask: true
            color: barButton.containsMouse || launcher.visible ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
            Behavior on color {
                ColorAnimation { duration: root.hoverDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: root.houseCurve }
            }
        }
    }

    Connections {
        target: Plasmoid
        function onActivated() { root.toggle() }
    }

    // ── Data ──────────────────────────────────────────────────────────────

    Kicker.KAStatsFavoritesModel {
        id: pins
        Component.onCompleted: initForClient(root.pinsClient)
    }

    Kicker.RecentUsageModel {
        id: recents
        shownItems: Kicker.RecentUsageModel.OnlyApps
        ordering: Kicker.RecentUsageModel.Recent
    }

    // One sub-model per runner (Apps, Files, Settings…), so results can be grouped
    Kicker.RunnerModel {
        id: runner
        appletInterface: root
        favoritesModel: pins
        mergeResults: false
        // Grouped mode needs the runners named; this order is the group order
        runners: ["krunner_services", "baloosearch", "krunner_recentdocuments", "krunner_systemsettings",
                  "calculator", "unitconverter", "locations", "krunner_placesrunner"]
        query: search.text
    }

    // Instantiators turn each model's rows into plain objects we can merge
    component Row: QtObject {
        required property int index
        required property var model
        readonly property string name: model.display ?? ""
        readonly property var icon: model.decoration
        readonly property string description: model.description ?? ""
        readonly property string favoriteId: model.favoriteId ?? ""
    }

    Instantiator {
        id: pinRows
        model: pins
        delegate: Row {}
        onObjectAdded: Qt.callLater(root.rebuildHome)
        onObjectRemoved: Qt.callLater(root.rebuildHome)
    }
    Instantiator {
        id: recentRows
        model: recents
        delegate: Row {}
        onObjectAdded: Qt.callLater(root.rebuildHome)
        onObjectRemoved: Qt.callLater(root.rebuildHome)
    }
    Instantiator {
        id: searchGroups
        model: runner
        delegate: QtObject {
            id: group
            required property int index
            readonly property var source: runner.modelForRow(index)
            readonly property string name: source ? source.description : ""
            readonly property Instantiator rows: Instantiator {
                model: group.source
                delegate: Row {}
                onObjectAdded: Qt.callLater(root.rebuildSearch)
                onObjectRemoved: Qt.callLater(root.rebuildSearch)
            }
        }
        onObjectAdded: Qt.callLater(root.rebuildSearch)
        onObjectRemoved: Qt.callLater(root.rebuildSearch)
    }
    Connections {
        target: pins
        function onFavoritesChanged() { Qt.callLater(root.rebuildHome) }
        function onRowsMoved() { Qt.callLater(root.rebuildHome) }
        function onModelReset() { Qt.callLater(root.rebuildHome) }
    }

    // above: "" | "divider" | a group header; subtitle: a second, muted line
    function entryFrom(row, source, i) {
        return { source: source, row: i, name: row.name, icon: row.icon,
                 description: row.description, favoriteId: row.favoriteId,
                 above: "", subtitle: "" }
    }

    function rebuildHome() {
        const out = []
        // A pin can use a different id than its recent entry (preferred://browser
        // vs brave-browser.desktop), so names dedupe too
        const pinned = new Set()
        const add = (r, source, i) => {
            out.push(entryFrom(r, source, i))
            pinned.add(r.favoriteId)
            pinned.add(r.name)
        }
        for (let i = 0; i < pinRows.count; i++) {
            const r = pinRows.objectAt(i)
            if (r) add(r, pins, i)
        }
        const pinCount = out.length
        for (let i = 0; i < recentRows.count; i++) {
            const r = recentRows.objectAt(i)
            if (r && !pinned.has(r.favoriteId) && !pinned.has(r.name) && !isHidden(r.favoriteId)) add(r, recents, i)
        }
        if (pinCount > 0 && out.length > pinCount)
            out[pinCount].above = "divider"  // thin line between pinned and recent
        homeEntries = out
        pinsVersion++

        // Keep the highlight on the app that was just pinned, unpinned or moved
        if (followId !== "") {
            const i = out.findIndex(e => e.favoriteId === followId)
            if (!searching) list.currentIndex = i >= 0 ? i : Math.min(list.currentIndex, out.length - 1)
            followId = ""
        }
    }
    property string followId: ""

    function rebuildSearch() {
        const out = []
        const seen = new Set()  // file search and recent documents can return the same file
        let lastLabel = ""
        for (let g = 0; g < searchGroups.count; g++) {
            const group = searchGroups.objectAt(g)
            if (!group) continue
            const label = groupLabels[group.name] ?? group.name
            for (let i = 0; i < group.rows.count; i++) {
                const r = group.rows.objectAt(i)
                if (!r || isHidden(r.favoriteId)) continue
                const e = entryFrom(r, group.source, i)
                // Files, settings etc. get their path/details on a second line; apps don't need it
                if (!isApp(e.favoriteId) && e.description && e.description !== e.name)
                    e.subtitle = e.description
                const key = e.name + "|" + e.subtitle
                if (seen.has(key)) continue
                seen.add(key)
                // One header per label, so runners sharing one ("Files") merge under it
                if (label !== lastLabel) {
                    e.above = label
                    lastLabel = label
                }
                out.push(e)
            }
        }
        searchEntries = out
        list.currentIndex = 0
    }

    // isFavorite() isn't a binding, so rows re-check it when this changes
    property int pinsVersion: 0
    function isPinned(entry) {
        return pinsVersion >= 0 && entry.favoriteId !== "" && pins.isFavorite(entry.favoriteId)
    }

    function setPinned(entry, pinned) {
        if (!entry || entry.favoriteId === "" || isPinned(entry) === pinned) return
        followId = entry.favoriteId
        if (pinned) pins.addFavorite(entry.favoriteId, -1)
        else pins.removeFavorite(entry.favoriteId)
    }

    function togglePin(entry) {
        if (entry) setPinned(entry, !isPinned(entry))
    }

    // Moves the highlighted pinned app up (-1) or down (+1) among the pins
    function movePin(step) {
        const entry = entries[list.currentIndex]
        if (searching || !entry || entry.source !== pins) return
        const to = entry.row + step
        if (to < 0 || to >= pinRows.count) return
        followId = entry.favoriteId
        pins.moveRow(entry.row, to)
    }

    function run(entry) {
        if (!entry) return
        entry.source.trigger(entry.row, "", null)
        close()
    }

    // ── Task manager ──────────────────────────────────────────────────────

    // One row per running app: systemd's app cgroups, like System Monitor's
    // Applications page. Sampled (every 2s) only while the launcher is open and
    // for a minute after, so reopening it shows live numbers right away.
    readonly property var taskAttributes: ["appName", "iconName", "menuId", "usage", "gpu_usage", "memory",
                                           "ioCharactersActuallyReadRate", "ioCharactersActuallyWrittenRate"]
    Process.ApplicationDataModel {
        id: apps
        enabled: launcher.visible || taskLinger.running
        enabledAttributes: root.taskAttributes
    }
    Timer { id: taskLinger; interval: 60000 }
    Process.ProcessController { id: processes }

    // Open windows: an app with one is listed first, the rest under "Background"
    TaskManager.TasksModel {
        id: windows
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByScreen: false
        filterByVirtualDesktop: false
        filterByActivity: false
    }

    Connections {
        target: apps
        function onDataChanged() { Qt.callLater(root.rebuildTasks) }
        function onRowsInserted() { Qt.callLater(root.rebuildTasks) }
        function onRowsRemoved() { Qt.callLater(root.rebuildTasks) }
        function onModelReset() { Qt.callLater(root.rebuildTasks) }
    }
    Connections {
        target: windows
        function onRowsInserted() { Qt.callLater(root.rebuildTasks) }
        function onRowsRemoved() { Qt.callLater(root.rebuildTasks) }
        function onModelReset() { Qt.callLater(root.rebuildTasks) }
    }

    // Header icons are the perf meter's (DESIGN.md Icons); cpu/gpu are % of the
    // whole CPU/GPU, ram KiB, disk read + write in bytes per second
    readonly property var taskColumns: [
        { key: "cpu",  icon: "leaves-cpu",             label: "CPU" },
        { key: "gpu",  icon: "mingcute-monitor-fill",  label: "GPU" },
        { key: "ram",  icon: "leaves-ram",             label: "Memory" },
        { key: "disk", icon: "mingcute-server-2-fill", label: "Disk read + write" },
    ]
    property string sortKey: "name"   // "name" or a column key (highest first)
    onSortKeyChanged: rebuildTasks()
    property int taskIndex: 0
    // Pids per row key, kept out of the ListModel (it would turn arrays into models)
    property var taskPids: ({})

    // Rows update in place every sample, so hover and the highlight don't flicker
    ListModel { id: taskRows }

    function rebuildTasks() {
        if (!launcher.visible) return
        const value = (r, name) => apps.data(apps.index(r, taskAttributes.indexOf(name)), Process.ProcessDataModel.Value)
        const maximum = name => apps.rowCount()
            ? apps.data(apps.index(0, taskAttributes.indexOf(name)), Process.ProcessDataModel.Maximum) || 0 : 0
        const cpuMax = maximum("usage") || 100   // 100 per core
        const ramMax = maximum("memory")

        // Windows by desktop file and by pid
        const W = TaskManager.AbstractTasksModel
        const windowById = {}, windowByPid = {}
        for (let w = 0; w < windows.rowCount(); w++) {
            const i = windows.index(w, 0)
            if (!windows.data(i, W.IsWindow)) continue
            const appId = windows.data(i, W.AppId) ?? ""
            const pid = windows.data(i, W.AppPid)
            if (appId && !(appId in windowById)) windowById[appId] = w
            if (pid && !(pid in windowByPid)) windowByPid[pid] = { row: w, appId: appId }
        }

        // Adds a row's pids and readings to another's
        const merge = (into, t) => {
            into.pids = into.pids.concat(t.pids)
            for (const k of ["cpu", "gpu", "ram", "disk"]) into[k] += t[k]
            into.windowRow = Math.max(into.windowRow, t.windowRow)
            t.merged = true
        }

        let list = []
        for (let r = 0; r < apps.rowCount(); r++) {
            const pids = apps.data(apps.index(r, 0), Process.ProcessDataModel.PIDs)
            if (!pids || !pids.length) continue
            const menuId = value(r, "menuId") || ""
            const name = value(r, "appName") || menuId
            const t = {
                key: menuId || name, name: name, icon: value(r, "iconName") || "", menuId: menuId,
                pids: Array.from(pids),
                cpu: (value(r, "usage") || 0) / cpuMax * 100,
                gpu: value(r, "gpu_usage") || 0,
                ram: value(r, "memory") || 0,
                disk: (value(r, "ioCharactersActuallyReadRate") || 0) + (value(r, "ioCharactersActuallyWrittenRate") || 0),
                windowRow: menuId in windowById ? windowById[menuId] : -1,
            }
            // Instances launched separately get a cgroup each; they're one row
            const same = list.find(o => o.key === t.key)
            if (same) merge(same, t)
            else list.push(t)
        }
        // A window found by pid instead. Chromium browsers move their main
        // process into a scope of their own (org.chromium.Chromium, no desktop
        // file); its window names the app it belongs to, so it's merged into it.
        for (const t of list) {
            if (t.windowRow >= 0) continue
            const w = t.pids.map(pid => windowByPid[pid]).find(w => w)
            if (!w) continue
            const owner = !t.menuId && w.appId ? list.find(o => o !== t && o.menuId === w.appId) : null
            t.windowRow = w.row
            if (owner) merge(owner, t)
        }
        list = list.filter(t => !t.merged)

        const byName = (a, b) => a.name.localeCompare(b.name)
        const order = sortKey === "name" ? byName : (a, b) => (b[sortKey] - a[sortKey]) || byName(a, b)
        const background = list.filter(t => t.windowRow < 0).sort(order)
        const rows = list.filter(t => t.windowRow >= 0).sort(order).concat(background)
        if (background.length) background[0].above = "Background"

        const currentKey = taskIndex < taskRows.count ? taskRows.get(taskIndex).key : ""
        const sameRows = rows.length === taskRows.count && rows.every((t, i) => taskRows.get(i).key === t.key)
        if (!sameRows) taskRows.clear()
        const pids = {}
        rows.forEach((t, i) => {
            pids[t.key] = t.pids
            const row = { key: t.key, name: t.name, icon: t.icon, cpu: t.cpu, gpu: t.gpu, ram: t.ram,
                          ramPercent: ramMax ? t.ram / ramMax * 100 : 0, disk: t.disk,
                          windowRow: t.windowRow, above: t.above ?? "" }
            if (sameRows) taskRows.set(i, row)
            else taskRows.append(row)
        })
        taskPids = pids
        // Keep the highlight on the same app as rows come, go and re-sort
        const i = rows.findIndex(t => t.key === currentKey)
        taskIndex = i >= 0 ? i : Math.max(0, Math.min(taskIndex, rows.length - 1))
    }

    function switchToTask(index) {
        const row = index >= 0 && index < taskRows.count ? taskRows.get(index).windowRow : -1
        if (row < 0) return
        close()
        windows.requestActivate(windows.makeModelIndex(row))
    }

    // The first ask is SIGTERM (the app can save and quit); asking again
    // within 5s, while it's still listed, is SIGKILL
    property string endingKey: ""
    Timer {
        id: endingTimer
        interval: 5000
        onTriggered: root.endingKey = ""
    }

    function endTask(index) {
        if (index < 0 || index >= taskRows.count) return
        const key = taskRows.get(index).key
        if (!taskPids[key]) return
        if (endingKey === key) {
            processes.sendSignal(taskPids[key], Process.Signal.KillSignal)
            endingKey = ""
            endingTimer.stop()
        } else {
            processes.sendSignal(taskPids[key], Process.Signal.TerminateSignal)
            endingKey = key
            endingTimer.restart()
        }
    }

    // Usage colors as in the perf meter: warning from 70%, critical from 85%
    function levelColor(percent) {
        if (percent >= 85) return Kirigami.Theme.negativeTextColor
        if (percent >= 70) return Kirigami.Theme.neutralTextColor
        return Kirigami.Theme.textColor
    }
    function formatMemory(kib) {
        const mib = kib / 1024
        if (mib < 1000) return Math.round(mib) + "M"
        const gib = mib / 1024
        return (gib < 10 ? gib.toFixed(1) : Math.round(gib)) + "G"
    }
    // The perf meter's network format: 1000 KiB/s and up switch to MiB/s
    function formatRate(bytes) {
        const kib = bytes / 1024
        if (kib < 1000) return Math.round(kib) + "K"
        const mib = kib / 1024
        return (mib < 10 ? mib.toFixed(1) : Math.round(mib)) + "M"
    }

    // ── Power & session ───────────────────────────────────────────────────

    Sessions.SessionManagement { id: session }
    KCoreAddons.KUser { id: user }

    // The launcher asks for confirmation itself, so Plasma's full-screen prompt is skipped
    readonly property int skipPrompt: Sessions.SessionManagement.ConfirmationMode.Skip

    readonly property var sideActions: [
        { icon: "system-lock-screen", label: "Lock",      run: () => session.lock() },
        { icon: "system-shutdown",    label: "Power Off", confirm: "Press again to power off", run: () => session.requestShutdown(skipPrompt) },
        { icon: "system-reboot",      label: "Restart",   confirm: "Press again to restart",   run: () => session.requestReboot(skipPrompt) },
        { icon: "system-suspend",     label: "Sleep",     run: () => session.suspend() },
        { icon: "leaves-log-out", label: "Log Out", confirm: "Press again to log out", run: () => session.requestLogout(skipPrompt) },
        { icon: "configure",          label: "System Settings", run: () => KCMUtils.KCMLauncher.openSystemSettings("") },
        { user: true,                 label: user.fullName || user.loginName, run: () => KCMUtils.KCMLauncher.openSystemSettings("kcm_users") },
    ]
    readonly property int dividerAfter: 4  // line between Log Out and System Settings
    property int sideIndex: 0

    // A confirm-needing action waits here for its second press
    property int confirmIndex: -1
    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: root.confirmIndex = -1
    }
    onSideIndexChanged: confirmIndex = -1
    onAreaChanged: confirmIndex = -1

    function runSide(i) {
        const action = sideActions[i]
        if (action.confirm && confirmIndex !== i) {
            confirmIndex = i
            confirmTimer.restart()
            return
        }
        confirmIndex = -1
        close()
        action.run()
    }

    // ── Open / close ──────────────────────────────────────────────────────

    function toggle() {
        if (launcher.visible && !closing) close()
        else open()
    }

    function open() {
        closeAnim.stop()
        closing = false
        search.text = ""
        area = "search"
        list.currentIndex = 0
        list.positionViewAtBeginning()
        sideIndex = 0
        confirmIndex = -1
        taskIndex = 0
        endingKey = ""
        rebuildHome()
        launcher.visible = true
        rebuildTasks()
        taskList.positionViewAtBeginning()
        launcher.requestActivate()
        search.forceActiveFocus()
        openAnim.restart()
    }

    property bool closing: false
    function close() {
        if (!launcher.visible || closing) return
        closing = true
        taskLinger.restart()
        openAnim.stop()
        closeAnim.restart()
    }

    // ── Window ────────────────────────────────────────────────────────────

    PlasmaCore.Window {
        id: launcher
        visible: false
        // Layer surfaces need a real size up front (0 is a protocol error)
        // The task manager widens it; the search column keeps its 680px-window width
        width: 680 + root.taskWidth + root.pad + 1
        height: 460
        LayerShell.Window.scope: "leaves-launcher"
        LayerShell.Window.anchors: LayerShell.Window.AnchorNone
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
        LayerShell.Window.wantsToBeOnActiveScreen: true
        onActiveChanged: if (!active) root.close()

        mainItem: Item {
            id: content
            width: launcher.width - launcher.leftPadding - launcher.rightPadding
            height: launcher.height - launcher.topPadding - launcher.bottomPadding

            ParallelAnimation {
                id: openAnim
                NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: root.openDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: root.houseCurve }
                NumberAnimation { target: content; property: "scale"; from: 0.96; to: 1; duration: root.openDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: root.houseCurve }
            }
            SequentialAnimation {
                id: closeAnim
                ParallelAnimation {
                    NumberAnimation { target: content; property: "opacity"; to: 0; duration: root.closeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: root.houseCurve }
                    NumberAnimation { target: content; property: "scale"; to: 0.96; duration: root.closeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: root.houseCurve }
                }
                ScriptAction { script: { launcher.visible = false; root.closing = false } }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: root.pad - 4   // the dialog frame already pads a little
                anchors.topMargin: root.pad     // 4px more breathing room top and bottom
                anchors.bottomMargin: root.pad
                spacing: root.pad

                // Left: task manager
                ColumnLayout {
                    // Fixed width, like the side panel
                    Layout.preferredWidth: root.taskWidth - root.pad
                    Layout.maximumWidth: root.taskWidth - root.pad
                    Layout.fillWidth: false
                    Layout.fillHeight: true
                    spacing: 8

                    // Column headers, as tall as the search field; click one to sort by it
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: root.rowHeight

                        Text {
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Tasks"
                            font.pointSize: 9
                            font.weight: Font.Medium
                            color: Kirigami.Theme.disabledTextColor
                            TapHandler { onTapped: root.sortKey = "name" }
                        }
                        RowLayout {
                            spacing: 0
                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            Repeater {
                                model: root.taskColumns
                                TaskHeader {}
                            }
                        }
                    }

                    ListView {
                        id: taskList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: taskRows
                        currentIndex: root.taskIndex
                        boundsBehavior: Flickable.StopAtBounds
                        highlightMoveDuration: 0
                        keyNavigationEnabled: false
                        delegate: TaskRow {}

                        layer.enabled: !atYBeginning || !atYEnd
                        layer.effect: GE.OpacityMask { maskSource: taskFadeMask }

                        Text {
                            anchors.centerIn: parent
                            visible: taskList.count === 0
                            text: apps.available ? "" : "Needs systemd app cgroups"
                            color: Kirigami.Theme.disabledTextColor
                            font.pointSize: 10
                        }
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    implicitWidth: 1
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.10)
                }

                // Middle: search + list
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: root.rowHeight
                        radius: 8
                        Kirigami.Theme.inherit: false
                        Kirigami.Theme.colorSet: Kirigami.Theme.Button
                        color: Kirigami.Theme.backgroundColor
                        // Neutral focus ring: the accent is kept for the highlighted row
                        border.width: 1
                        border.color: root.area === "search" ? Qt.alpha(Kirigami.Theme.textColor, 0.16) : "transparent"
                        Behavior on border.color {
                            ColorAnimation { duration: root.hoverDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: root.houseCurve }
                        }

                        Kirigami.Icon {
                            id: searchIcon
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16
                            source: "search"
                            isMask: true
                            color: Kirigami.Theme.disabledTextColor
                        }

                        TextInput {
                            id: search
                            anchors { left: searchIcon.right; right: parent.right; leftMargin: 8; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            color: Kirigami.Theme.textColor
                            selectionColor: Kirigami.Theme.highlightColor
                            selectedTextColor: Kirigami.Theme.highlightedTextColor
                            font.pointSize: 10
                            clip: true
                            onTextChanged: root.area = "search"

                            Text {
                                anchors.fill: parent
                                visible: !search.text
                                verticalAlignment: Text.AlignVCenter
                                text: "Search apps and files"
                                color: Kirigami.Theme.disabledTextColor
                                font: search.font
                            }

                            Keys.onPressed: event => root.handleKey(event)
                        }
                    }

                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: root.entries
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds
                        highlightMoveDuration: 0
                        keyNavigationEnabled: false
                        delegate: EntryRow {}

                        // Scroll hint: rows fade out at an edge with more content past it
                        layer.enabled: !atYBeginning || !atYEnd
                        layer.effect: GE.OpacityMask { maskSource: fadeMask }

                        Text {
                            anchors.centerIn: parent
                            visible: list.count === 0
                            text: root.searching ? (runner.querying ? "" : "No results") : "No recent apps yet"
                            color: Kirigami.Theme.disabledTextColor
                            font.pointSize: 10
                        }
                    }
                }

                // Vertical divider between the list and the side panel
                Rectangle {
                    Layout.fillHeight: true
                    implicitWidth: 1
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.10)
                }

                // Right: power & session, settings, user
                ColumnLayout {
                    // Fixed width; without the max it inherits fillWidth from its rows
                    Layout.preferredWidth: root.sideWidth - root.pad
                    Layout.maximumWidth: root.sideWidth - root.pad
                    Layout.fillWidth: false
                    Layout.fillHeight: true
                    spacing: 2

                    Repeater {
                        model: root.dividerAfter + 1
                        SideRow { required property int index; actionIndex: index }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        Layout.bottomMargin: 6
                        implicitHeight: 1
                        color: Qt.alpha(Kirigami.Theme.textColor, 0.10)
                    }
                    SideRow { actionIndex: root.dividerAfter + 1 }
                    Item { Layout.fillHeight: true }
                    SideRow { actionIndex: root.sideActions.length - 1 }
                }
            }

            ScrollFade { id: fadeMask; view: list }
            ScrollFade { id: taskFadeMask; view: taskList }
        }
    }

    // ── Keyboard ──────────────────────────────────────────────────────────

    function handleKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier
        const alt = event.modifiers & Qt.AltModifier
        const arrows = [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down]
        if (alt && area === "tasks" && arrows.includes(event.key)) {
            if (event.key === Qt.Key_Left) endTask(taskIndex)
            event.accepted = true
            return
        }
        if (alt && (area === "search" || area === "list") && handlePinKey(event.key)) {
            event.accepted = true
            list.positionViewAtIndex(list.currentIndex, ListView.Contain)
            return
        }
        switch (event.key) {
        case Qt.Key_Escape:
            if (searching) search.text = ""
            else close()
            break
        case Qt.Key_Down:
            if (area === "tasks") taskIndex = Math.min(taskIndex + 1, taskRows.count - 1)
            else if (area === "side") sideIndex = Math.min(sideIndex + 1, sideActions.length - 1)
            else if (area === "search") {
                // While typing, row 0 is already highlighted, so Down goes to row 1
                if (list.count) { area = "list"; list.currentIndex = searching ? Math.min(1, list.count - 1) : 0 }
            }
            else list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1)
            break
        case Qt.Key_Up:
            if (area === "tasks") taskIndex = Math.max(taskIndex - 1, 0)
            else if (area === "side") sideIndex = Math.max(sideIndex - 1, 0)
            else if (area === "list") {
                if (list.currentIndex <= (searching ? 1 : 0)) { area = "search"; list.currentIndex = 0 }
                else list.currentIndex--
            }
            break
        case Qt.Key_Right:
            if (area === "side") break
            if (area === "tasks") { area = areaBeforeTasks; break }
            if (area === "search" && search.cursorPosition < search.text.length) { event.accepted = false; return }
            goToSide()
            break
        case Qt.Key_Left:
            if (area === "side") area = areaBeforeSide
            else if (area === "search" && search.cursorPosition > 0) { event.accepted = false; return }
            else if (area !== "tasks") goToTasks()
            break
        case Qt.Key_Tab:
            cycleArea(+1)
            break
        case Qt.Key_Backtab:
            cycleArea(-1)
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (area === "side") runSide(sideIndex)
            else if (area === "tasks") switchToTask(taskIndex)
            else run(entries[list.currentIndex])
            break
        case Qt.Key_P:
            if (!ctrl || area === "side" || area === "tasks") { event.accepted = false; return }
            togglePin(entries[list.currentIndex])
            break
        default:
            event.accepted = false
            return
        }
        event.accepted = true
        list.positionViewAtIndex(list.currentIndex, ListView.Contain)
        taskList.positionViewAtIndex(taskIndex, ListView.Contain)
    }

    function goToSide() {
        areaBeforeSide = area
        area = "side"
    }

    function goToTasks() {
        areaBeforeTasks = area
        area = "tasks"
    }

    // Tab order, left to right: tasks → search → list → side panel (the list is skipped when empty)
    function cycleArea(step) {
        const order = list.count ? ["tasks", "search", "list", "side"] : ["tasks", "search", "side"]
        const next = order[(order.indexOf(area) + step + order.length) % order.length]
        if (next === "side") goToSide()
        else if (next === "tasks") goToTasks()
        else {
            if (next === "list") list.currentIndex = 0
            area = next
        }
    }

    // Alt+arrows act on the highlighted row: the list's, or the first result while typing
    function handlePinKey(key) {
        const highlighted = area === "list" || (area === "search" && searching)
        const entry = highlighted ? entries[list.currentIndex] : null
        switch (key) {
        case Qt.Key_Right: setPinned(entry, true); return true
        case Qt.Key_Left:  setPinned(entry, false); return true
        case Qt.Key_Up:    if (area === "list") movePin(-1); return true
        case Qt.Key_Down:  if (area === "list") movePin(+1); return true
        }
        return false
    }

    // ── Rows ──────────────────────────────────────────────────────────────

    // The keyboard highlight is the one accented thing; hover stays a neutral tint
    component RowBackground: Rectangle {
        property bool selected
        property bool hovered
        property color tint: Kirigami.Theme.highlightColor
        radius: 8
        color: selected ? Qt.alpha(tint, 0.18)
             : hovered ? Qt.alpha(Kirigami.Theme.textColor, 0.06)
             : "transparent"
        Behavior on color {
            ColorAnimation { duration: root.hoverDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: root.houseCurve }
        }
    }

    component EntryRow: Item {
        id: entryRow
        required property var modelData
        required property int index
        readonly property bool pinned: root.isPinned(modelData)
        readonly property bool hasDivider: modelData.above === "divider"
        readonly property bool hasHeader: modelData.above !== "" && !hasDivider
        // Space above the row: divider 4 + 1 + 4; header text plus a gap from the previous group
        readonly property int aboveHeight: hasDivider ? 9 : hasHeader ? (index === 0 ? 20 : 28) : 0

        width: ListView.view.width
        height: aboveHeight + rowBackground.height

        Rectangle {
            visible: entryRow.hasDivider
            x: 8
            y: 4
            width: parent.width - 16
            height: 1
            color: Qt.alpha(Kirigami.Theme.textColor, 0.10)
        }

        Text {
            visible: entryRow.hasHeader
            x: 8
            anchors { bottom: rowBackground.top; bottomMargin: 4 }
            text: entryRow.modelData.above
            font.pointSize: 9
            font.weight: Font.Medium
            color: Kirigami.Theme.disabledTextColor
        }

        RowBackground {
            id: rowBackground
            y: entryRow.aboveHeight
            width: parent.width
            height: entryRow.modelData.subtitle ? root.twoLineRowHeight : root.rowHeight
            hovered: mouse.containsMouse
            // While typing, the first result is highlighted so Enter runs it
            selected: entryRow.index === list.currentIndex
                      && (root.area === "list" || (root.area === "search" && root.searching))

            Kirigami.Icon {
                id: appIcon
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24
                source: entryRow.modelData.icon
            }

            Column {
                anchors { left: appIcon.right; leftMargin: 12; right: pinIcon.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 0
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    font.pointSize: 10
                    color: Kirigami.Theme.textColor
                    text: entryRow.modelData.name
                }
                Text {
                    visible: text !== ""
                    width: parent.width
                    elide: Text.ElideMiddle  // paths: keep the start and the file's folder
                    font.pointSize: 9
                    color: Kirigami.Theme.disabledTextColor
                    text: entryRow.modelData.subtitle
                }
            }

            // Pin indicator at the end: always shown when pinned, faint on hover otherwise
            Kirigami.Icon {
                id: pinIcon
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                width: 16; height: 16
                source: "pin"
                isMask: true
                visible: entryRow.modelData.favoriteId !== ""
                color: Kirigami.Theme.textColor
                opacity: entryRow.pinned || pinMouse.containsMouse ? 0.7 : mouse.containsMouse ? 0.25 : 0
                Behavior on opacity {
                    NumberAnimation { duration: root.hoverDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: root.houseCurve }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: event => {
                    if (event.button === Qt.RightButton) root.togglePin(entryRow.modelData)
                    else root.run(entryRow.modelData)
                }
            }
            MouseArea {
                id: pinMouse
                anchors.fill: pinIcon
                anchors.margins: -6
                hoverEnabled: true
                enabled: pinIcon.visible
                onClicked: root.togglePin(entryRow.modelData)
            }
        }
    }

    // A list's scroll hint: an alpha mask (only drawn through the effect) that
    // fades rows out at an edge with more content past it
    component ScrollFade: Rectangle {
        id: fade
        required property Flickable view
        visible: false
        width: view.width
        height: view.height
        readonly property real edge: root.fadeSize / Math.max(height, 1)
        gradient: Gradient {
            GradientStop { position: 0; color: fade.view.atYBeginning ? "black" : "transparent" }
            GradientStop { position: fade.edge; color: "black" }
            GradientStop { position: 1 - fade.edge; color: "black" }
            GradientStop { position: 1; color: fade.view.atYEnd ? "black" : "transparent" }
        }
    }

    // Column header icon; the sorted column is drawn in the text color
    component TaskHeader: Item {
        id: header
        required property var modelData
        readonly property bool active: root.sortKey === modelData.key
        Layout.preferredWidth: root.taskCellWidth
        height: 16

        Kirigami.Icon {
            anchors.right: parent.right
            width: 16; height: 16
            source: header.modelData.icon
            isMask: true
            color: header.active || headerHover.hovered ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
            Behavior on color {
                ColorAnimation { duration: root.hoverDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: root.houseCurve }
            }
        }
        HoverHandler { id: headerHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.sortKey = header.active ? "name" : header.modelData.key }
        PlasmaComponents.ToolTip {
            text: header.modelData.label
            visible: headerHover.hovered
        }
    }

    // A right-aligned reading; idle ones (nothing happening) are muted
    component TaskCell: Text {
        property real level
        property bool idle
        Layout.preferredWidth: root.taskCellWidth
        horizontalAlignment: Text.AlignRight
        font.pointSize: 9
        color: idle ? Kirigami.Theme.disabledTextColor : root.levelColor(level)
    }

    component TaskRow: Item {
        id: taskRow
        required property int index
        required property string key
        required property string name
        required property string icon
        required property real cpu
        required property real gpu
        required property real ram
        required property real ramPercent
        required property real disk
        required property int windowRow
        required property string above
        readonly property bool ending: root.endingKey === key
        readonly property bool hovered: taskMouse.containsMouse || endMouse.containsMouse
        readonly property int aboveHeight: above !== "" ? (index === 0 ? 20 : 28) : 0

        width: ListView.view.width
        height: aboveHeight + root.taskRowHeight

        Text {
            visible: taskRow.above !== ""
            x: 8
            anchors { bottom: taskBackground.top; bottomMargin: 4 }
            text: taskRow.above
            font.pointSize: 9
            font.weight: Font.Medium
            color: Kirigami.Theme.disabledTextColor
        }

        RowBackground {
            id: taskBackground
            y: taskRow.aboveHeight
            width: parent.width
            height: root.taskRowHeight
            hovered: taskRow.hovered
            selected: (root.area === "tasks" && root.taskIndex === taskRow.index) || taskRow.ending
            tint: taskRow.ending ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor

            Kirigami.Icon {
                id: taskIcon
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24
                source: taskRow.icon || "application-x-executable"
            }

            // Background apps (no window) in the muted color
            Text {
                anchors {
                    left: taskIcon.right; leftMargin: 8
                    right: cells.left; rightMargin: taskRow.hovered ? 28 : 4
                    verticalCenter: parent.verticalCenter
                }
                elide: Text.ElideRight
                font.pointSize: 10
                color: taskRow.ending ? Kirigami.Theme.negativeTextColor
                     : taskRow.windowRow >= 0 ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                text: taskRow.ending ? "Again to force quit" : taskRow.name
            }

            // End task, shown on hover
            Kirigami.Icon {
                id: endIcon
                anchors { right: cells.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: 16; height: 16
                source: "mingcute-close-fill"
                isMask: true
                color: endMouse.containsMouse ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                opacity: endMouse.containsMouse ? 1 : taskRow.hovered ? 0.5 : 0
                Behavior on opacity {
                    NumberAnimation { duration: root.hoverDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: root.houseCurve }
                }
            }

            RowLayout {
                spacing: 0
                id: cells
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                TaskCell { text: Math.round(taskRow.cpu) + "%"; level: taskRow.cpu; idle: taskRow.cpu < 0.5 }
                TaskCell { text: Math.round(taskRow.gpu) + "%"; level: taskRow.gpu; idle: taskRow.gpu < 0.5 }
                TaskCell { text: root.formatMemory(taskRow.ram); level: taskRow.ramPercent }
                TaskCell { text: root.formatRate(taskRow.disk); idle: taskRow.disk < 512 }
            }

            MouseArea {
                id: taskMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: taskRow.windowRow >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.switchToTask(taskRow.index)
            }
            MouseArea {
                id: endMouse
                anchors.fill: endIcon
                anchors.margins: -6
                hoverEnabled: true
                onClicked: root.endTask(taskRow.index)
            }
        }
    }

    component SideRow: RowBackground {
        id: sideRow
        property int actionIndex
        readonly property var action: root.sideActions[actionIndex]
        readonly property bool confirming: root.confirmIndex === actionIndex

        Layout.fillWidth: true
        implicitHeight: action.user ? 40 : 32
        hovered: sideMouse.containsMouse
        selected: (root.area === "side" && root.sideIndex === actionIndex) || confirming
        tint: confirming ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor

        KirigamiComponents.Avatar {
            id: avatar
            visible: !!sideRow.action.user
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 24; height: 24
            name: sideRow.action.label
            source: user.faceIconUrl
            cache: false
        }
        Kirigami.Icon {
            id: sideIcon
            visible: !sideRow.action.user
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16
            source: sideRow.action.icon ?? ""
            isMask: true
            color: sideRow.confirming ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
        }
        Text {
            anchors { left: (sideRow.action.user ? avatar : sideIcon).right; leftMargin: 12; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            elide: Text.ElideRight
            font.pointSize: 10
            color: sideRow.confirming ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
            text: sideRow.confirming ? sideRow.action.confirm : sideRow.action.label
        }
        MouseArea {
            id: sideMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.runSide(sideRow.actionIndex)
        }
    }
}
