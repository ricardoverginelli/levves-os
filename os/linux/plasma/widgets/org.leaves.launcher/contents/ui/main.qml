// Centered launcher. Subtle icon in the bar; Super or a click opens a window
// centered on the active screen (layer shell, no anchors). Drawn like the terminal
// launcher (agents/launcher): flat, all mono, lines only between the areas and in
// the task table.
//
//   TASKS · BY LOAD  CPU GPU VRAM RAM DISK │ › search ───────────── │ Lock
//   ───────────────────────────────────────│ pinned apps (pin icon) │ Power Off
//   SYSTEM  used / available, and the last │ then recent apps, one  │ Restart
//           two minutes under each         │ list; or search        │ Sleep
//   ───────────────────────────────────────│ results grouped (APPS, │ Log Out
//   every running app, one flat list,      │ FILES…), or a folder   │
//   highest load first (no window: muted)  │ (FOLDERS, FILES)       │ System Settings
//                                          │                        │ (user)
//
// Keys: focus stays in the search field; arrows move a highlight between
// areas. Down = list, Right = side panel (from search only when the cursor is
// at the end), Left = task manager (from search only when the cursor is at the
// start), Left/Right from a side area = back, Tab/Shift+Tab = next/previous
// area, Enter = run, Esc = close. Power Off, Restart and Log Out ask for a
// second Enter/click.
// Folders: "/" in the empty field lists the home folder ("~/"); the text after
// the last "/" filters it. Enter opens a folder (or a file, in its app), Backspace
// past a "/" goes up, Shift+Enter shows the highlighted folder (or the one being
// listed) in Dolphin. Folders pin like apps; Enter on a pinned one lists it.
// Pins: Alt+Right pins, Alt+Left unpins, Alt+Up/Down reorders pinned apps
// (Ctrl+P toggles). Right-click a row (or click its pin) to pin/unpin it.
// Tasks: Enter (or a click) switches to the app's window; Alt+Left (or its ×)
// closes the app's windows (SIGTERM if it has none), and doing it again within
// 5s force-quits it. Rows are sorted by load; click a column header to sort by
// it (again for load), or "Tasks" for by name. Alt+1-5 do the same as the
// column headers, from anywhere in the launcher.
import QtQuick
import QtQuick.Layouts
import QtCore
import Qt.labs.folderlistmodel
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
import org.kde.ksysguard.sensors as Sensors
import org.kde.taskmanager as TaskManager
import Levves
import "../../../../../leaves"

PlasmoidItem {
    id: root

    // Levves motion and spacing (design/DESIGN.md)
    readonly property int houseCurve: Easing.OutQuint
    readonly property int hoverDuration: Theme.durationHover
    readonly property int edgeMargin: Theme.space12   // same as the perf meter's
    readonly property int pad: Theme.space12
    readonly property int rowHeight: 30
    readonly property int twoLineRowHeight: 46
    readonly property int sideWidth: 210
    readonly property int taskWidth: 750
    readonly property int taskRowHeight: 30
    readonly property int taskCellWidth: 96   // room for "used / available" on one line
    // GPU's total names both cards ("N 88% · I 0%"), so its column is wider
    function columnWidth(key) { return key === "gpu" ? 124 : taskCellWidth }
    readonly property int columnGap: 24       // each side of the rules between the areas
    readonly property string mono: Theme.typeFamilyMono
    readonly property int iconX: 14                       // a row's icon
    readonly property int nameX: iconX + 20 + 12          // a row's name, and the prompt's text

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
    readonly property var entries: navigating ? navEntries : searching ? searchEntries : homeEntries
    // While typing, the first row is highlighted so Enter runs it; not in a folder
    // with nothing typed yet, where Enter would open whatever happens to be first
    readonly property bool autoHighlight: searching && !(navigating && navFilter === "")
    property var homeEntries: []
    property var searchEntries: []

    activationTogglesExpanded: false
    // The bar icon is the "full" representation: Plasma never creates a compact
    // one for widgets without a full one
    preferredRepresentation: fullRepresentation
    toolTipMainText: "Launcher"
    toolTipSubText: "Apps, files, power and session"

    // The bar button is a key (design/DESIGN.md Pieces), held down while the launcher is open
    fullRepresentation: Item {
        id: barButton
        implicitWidth: Theme.space8 + barKey.width
        Layout.minimumWidth: implicitWidth
        Layout.maximumWidth: implicitWidth
        Layout.fillHeight: true

        Key {
            id: barKey
            x: Theme.space8
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 22
            leftPadding: 0
            rightPadding: 0
            current: launcher.visible
            onClicked: root.toggle()
            contentItem: Item {
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    source: "leaves-leaf"
                    isMask: true
                    color: Theme.text
                }
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
        query: root.navigating ? "" : search.text
    }

    // Instantiators turn each model's rows into plain objects we can merge
    component RowData: QtObject {
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
        delegate: RowData {}
        onObjectAdded: Qt.callLater(root.rebuildHome)
        onObjectRemoved: Qt.callLater(root.rebuildHome)
    }
    Instantiator {
        id: recentRows
        model: recents
        delegate: RowData {}
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
                delegate: RowData {}
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

    // above: "" or a group's heading; count: its rows (set by countGroups); subtitle: a
    // second, muted line
    function entryFrom(row, source, i) {
        return { source: source, row: i, name: row.name, icon: row.icon,
                 description: row.description, favoriteId: row.favoriteId,
                 above: "", count: 0, subtitle: "" }
    }

    function countGroups(out) {
        let head = null
        for (const e of out) {
            if (e.above) { head = e; e.count = 0 }
            if (head) head.count++
        }
        return out
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
        for (let i = 0; i < recentRows.count; i++) {
            const r = recentRows.objectAt(i)
            if (r && !pinned.has(r.favoriteId) && !pinned.has(r.name) && !isHidden(r.favoriteId)) add(r, recents, i)
        }
        homeEntries = out   // one list: pinned apps first (they show their pin), then recent
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
        searchEntries = countGroups(out)
        if (!navigating) list.currentIndex = 0
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
        if (entry.isDir !== undefined) {
            if (entry.isDir) search.text = navTyped + entry.name + "/"
            else { Qt.openUrlExternally(entry.path); close() }
            return
        }
        if (entry.favoriteId.startsWith("file://")) { openPinnedPath(entry); return }
        entry.source.trigger(entry.row, "", null)
        close()
    }

    // ── Folder navigator ──────────────────────────────────────────────────

    readonly property string homePath: decodeURIComponent(
        StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace(/^file:\/\//, ""))
    // The field is the path: "~/repos/lev" lists ~/repos filtered by "lev"
    readonly property bool navigating: search.text.startsWith("/") || search.text.startsWith("~/")
    readonly property string navTyped: navigating ? search.text.slice(0, search.text.lastIndexOf("/") + 1) : ""
    readonly property string navFilter: navigating ? search.text.slice(search.text.lastIndexOf("/") + 1) : ""
    readonly property string navFolder: navTyped.startsWith("~") ? homePath + navTyped.slice(1) : navTyped
    property var navEntries: []
    readonly property var navCrumbs: {
        const parts = navTyped.split("/").slice(0, -1)
        return parts.map((part, i) => ({ name: part === "" ? "/" : part, path: parts.slice(0, i + 1).join("/") + "/" }))
    }
    onNavFilterChanged: Qt.callLater(rebuildNav)

    FolderListModel {
        id: folder
        folder: root.navigating ? "file://" + root.navFolder : ""
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: root.navFilter.startsWith(".")   // dotfiles once a "." is typed, like a shell
        sortCaseSensitive: false
        onFolderChanged: Qt.callLater(root.rebuildNav)
        onStatusChanged: Qt.callLater(root.rebuildNav)
        onCountChanged: Qt.callLater(root.rebuildNav)
    }

    // The home folder's own folders get their themed icons
    readonly property var homeFolderIcons: ({
        "Desktop": "folder-desktop", "Documents": "folder-documents", "Downloads": "folder-download",
        "Music": "folder-music", "Pictures": "folder-pictures", "Videos": "folder-videos",
        "Public": "folder-public", "Templates": "folder-templates",
    })
    // No QML module maps a file to its type's icon, so the common extensions are listed
    readonly property var extensionIcons: ({
        pdf: "application-pdf", txt: "text-plain", md: "text-markdown", log: "text-x-log",
        json: "application-json", xml: "application-xml", yaml: "application-x-yaml", yml: "application-x-yaml",
        toml: "text-plain", ini: "text-plain", conf: "text-plain",
        qml: "text-x-qml", js: "text-javascript", mjs: "text-javascript", ts: "text-x-typescript",
        tsx: "text-x-typescript", jsx: "text-javascript", py: "text-x-python", sh: "application-x-shellscript",
        c: "text-x-csrc", h: "text-x-chdr", cpp: "text-x-c++src", rs: "text-rust", go: "text-x-go",
        html: "text-html", css: "text-css", svg: "image-svg+xml",
        png: "image-png", jpg: "image-jpeg", jpeg: "image-jpeg", gif: "image-gif", webp: "image-x-generic",
        mp3: "audio-x-generic", flac: "audio-x-generic", wav: "audio-x-generic", ogg: "audio-x-generic",
        mp4: "video-x-generic", mkv: "video-x-generic", webm: "video-x-generic", mov: "video-x-generic",
        zip: "application-zip", gz: "application-x-compressed-tar", xz: "application-x-compressed-tar",
        tar: "application-x-tar", "7z": "application-x-7z-compressed", rar: "application-x-rar",
        doc: "x-office-document", docx: "x-office-document", odt: "x-office-document",
        xls: "x-office-spreadsheet", xlsx: "x-office-spreadsheet", ods: "x-office-spreadsheet", csv: "text-csv",
        ppt: "x-office-presentation", pptx: "x-office-presentation", odp: "x-office-presentation",
        rpm: "application-x-rpm", iso: "application-x-cd-image", desktop: "application-x-desktop",
    })
    function fileIcon(name) {
        const dot = name.lastIndexOf(".")
        return (dot > 0 && extensionIcons[name.slice(dot + 1).toLowerCase()]) || "text-x-generic"
    }

    // Folders first, then files; in each, an exact match, then names starting with
    // the filter, then names containing it. Going up ("~/repos" after "~/repos/")
    // so lands on the folder just left.
    function rebuildNav() {
        if (!navigating) return
        const f = navFilter.toLowerCase()
        const inHome = navFolder === homePath + "/"
        const out = []
        for (let i = 0; i < folder.count; i++) {
            const name = folder.get(i, "fileName")
            const lower = name.toLowerCase()
            const at = f ? lower.indexOf(f) : 0
            if (at < 0) continue
            const isDir = folder.get(i, "fileIsDir")
            const path = folder.get(i, "fileUrl").toString()
            out.push({ source: null, row: i, name: name, description: "", subtitle: "", above: "",
                       icon: isDir ? (inHome && homeFolderIcons[name]) || "folder" : fileIcon(name),
                       favoriteId: path, path: path, isDir: isDir,
                       rank: !f || lower === f ? 0 : at === 0 ? 1 : 2 })
        }
        out.sort((a, b) => (b.isDir - a.isDir) || (a.rank - b.rank) || (a.row - b.row))
        const folders = out.findIndex(e => e.isDir), files = out.findIndex(e => !e.isDir)
        if (folders >= 0) out[folders].above = "Folders"
        if (files >= 0) out[files].above = "Files"
        navEntries = countGroups(out)
        list.currentIndex = 0
        list.positionViewAtBeginning()
    }

    // Shift+Enter: the highlighted folder, or the one being listed, in the file manager
    function showInFileManager() {
        const highlighted = area === "list" || (area === "search" && autoHighlight)
        const entry = highlighted ? entries[list.currentIndex] : null
        if (navigating) Qt.openUrlExternally(entry && entry.isDir ? entry.path : "file://" + navFolder)
        else if (entry && entry.favoriteId.startsWith("file://")) Qt.openUrlExternally(entry.favoriteId)
        else return
        close()
    }

    // A pinned folder is listed in the navigator, a pinned file opens. The pin is
    // only a URL, so its parent folder is looked up to tell which it is.
    property var pendingPin: null
    function openPinnedPath(entry) {
        const path = decodeURIComponent(entry.favoriteId.replace(/^file:\/\//, "")).replace(/\/$/, "")
        pendingPin = { path: path, url: entry.favoriteId, name: path.slice(path.lastIndexOf("/") + 1) }
        const parent = "file://" + path.slice(0, path.lastIndexOf("/") + 1)
        if (pinProbe.folder.toString() === parent && pinProbe.status === FolderListModel.Ready) resolvePin()
        else pinProbe.folder = parent
    }
    function resolvePin() {
        const pin = pendingPin
        if (!pin || pinProbe.status !== FolderListModel.Ready) return
        pendingPin = null
        const i = pinProbe.indexOf("file://" + pin.path)
        if (i >= 0 && pinProbe.get(i, "fileIsDir")) {
            search.text = (pin.path === homePath || pin.path.startsWith(homePath + "/")
                           ? "~" + pin.path.slice(homePath.length) : pin.path) + "/"
        } else {
            Qt.openUrlExternally(pin.url)
            close()
        }
    }
    FolderListModel {
        id: pinProbe
        showHidden: true
        onStatusChanged: root.resolvePin()
    }

    // ── Task manager ──────────────────────────────────────────────────────

    // One row per running app: systemd's app cgroups, like System Monitor's
    // Applications page. Sampled (every 2s) only while the launcher is open and
    // for a minute after, so reopening it shows live numbers right away.
    readonly property var taskAttributes: ["appName", "iconName", "menuId", "usage", "gpu_usage", "gpu_memory", "memory",
                                           "ioCharactersActuallyReadRate", "ioCharactersActuallyWrittenRate"]
    Process.ApplicationDataModel {
        id: apps
        enabled: launcher.visible || taskLinger.running
        enabledAttributes: root.taskAttributes
        cgroupMapping: Object.keys(root.taskServices).reduce((map, unit) => { map[unit] = unit; return map }, ({}))
    }
    Timer { id: taskLinger; interval: 60000 }

    // Our own user services, listed under "Services". They're outside the app-*
    // cgroups, so the model only sees them through cgroupMapping (the value is a
    // group key: non-empty text, one per row, or units vanish or merge), and names
    // them by the end of their cgroup path: the unit is the row's identity.
    readonly property var taskServices: ({
        "capture-replay.service":    { name: "Capture Replay", icon: "mingcute-video-fill" },
        "leaves-music-dock.service": { name: "Leaves Music",   icon: "mingcute-music-2-fill" },
        "mic-mute-sound.service":    { name: "Mic Mute Sound", icon: "mingcute-mic-fill" },
        "s25-control.service":       { name: "S25 Control",    icon: "mingcute-midi-fill" },
        "soloist.service":           { name: "Soloist",        icon: "mingcute-headphone-fill" },
    })
    Process.ProcessController { id: processes }

    // Open windows: Enter switches to one, and apps without one get a muted name
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
    // whole CPU/GPU, vram and ram KiB, disk read + write in bytes per second
    readonly property var taskColumns: [
        { key: "cpu",  short: "CPU",  label: "CPU" },
        { key: "gpu",  short: "GPU",  label: "GPU" },
        { key: "vram", short: "VRAM", label: "Video memory" },
        { key: "ram",  short: "RAM",  label: "Memory" },
        { key: "disk", short: "Disk", label: "Disk read + write" },
    ]
    // "load" (default), "name", or a column key (highest first). Load is an app's
    // largest share of the machine: CPU or GPU %, VRAM or RAM as % of the total, or
    // disk against diskCeiling. Its column (the lead) is the row's one bright cell.
    property string sortKey: "load"
    onSortKeyChanged: { sortNow = true; rebuildTasks() }
    function sortBy(column) { sortKey = sortKey === column ? "load" : column }
    readonly property real diskCeiling: 100 * 1024 * 1024   // 100 MiB/s counts as 100%
    // Load is smoothed over a few samples (per row key) so the order settles
    property var taskLoads: ({})
    // While the pointer or the keyboard is in the list the rows keep their order
    // (new apps go to the end); it re-sorts on the next sample after that
    readonly property bool tasksFrozen: area === "tasks" || taskHover.hovered
    property bool sortNow: false

    // The machine's totals, shown under the column headers. From the system sensors,
    // not the rows' sum: the kernel, KWin and anything outside an app cgroup count too.
    // gpu0 is the NVIDIA card, gpu1 Intel's (its memory is RAM, so VRAM is NVIDIA's).
    // They're read all the time (five cheap reads every 2s) so the history is there on opening.
    component Total: Sensors.Sensor { updateRateLimit: 2000 }
    Total { id: cpuTotal;     sensorId: "cpu/all/usage" }
    Total { id: cpuThreads;   sensorId: "cpu/all/coreCount" }
    Total { id: nvidiaTotal;  sensorId: "gpu/gpu0/usage" }
    Total { id: intelTotal;   sensorId: "gpu/gpu1/usage" }
    Total { id: vramUsed;     sensorId: "gpu/gpu0/usedVram" }
    Total { id: vramTotal;    sensorId: "gpu/gpu0/totalVram" }
    Total { id: ramUsed;      sensorId: "memory/physical/used" }
    Total { id: ramTotal;     sensorId: "memory/physical/total" }
    Total { id: diskRead;     sensorId: "disk/all/read" }
    Total { id: diskWrite;    sensorId: "disk/all/write" }

    // The totals' last two minutes, one sample every 2s: percent of what's available
    // (GPU: the busier of the two), disk in bytes per second
    readonly property int historyLength: 60
    property var history: ({ cpu: [], gpu: [], vram: [], ram: [], disk: [] })
    Timer { interval: 2000; running: true; repeat: true; onTriggered: root.sampleTotals() }
    function sampleTotals() {
        const percent = (used, total) => total ? (used ?? 0) / total * 100 : 0
        const now = {
            cpu: cpuTotal.value ?? 0,
            gpu: Math.max(nvidiaTotal.value ?? 0, intelTotal.value ?? 0),
            vram: percent(vramUsed.value, vramTotal.value),
            ram: percent(ramUsed.value, ramTotal.value),
            disk: (diskRead.value ?? 0) + (diskWrite.value ?? 0),
        }
        const next = {}
        for (const key in now) next[key] = history[key].concat([now[key]]).slice(-historyLength)
        history = next
    }
    property int taskIndex: 0
    // Pids and window rows per row key, kept out of the ListModel (it would turn arrays into models)
    property var taskPids: ({})
    property var taskWindows: ({})

    // Rows update in place every sample, so hover and the highlight don't flicker
    ListModel { id: taskRows }

    function rebuildTasks() {
        if (!launcher.visible) return
        const value = (r, name) => apps.data(apps.index(r, taskAttributes.indexOf(name)), Process.ProcessDataModel.Value)
        const maximum = name => apps.rowCount()
            ? apps.data(apps.index(0, taskAttributes.indexOf(name)), Process.ProcessDataModel.Maximum) || 0 : 0
        const cpuMax = maximum("usage") || 100   // 100 per core
        const ramMax = maximum("memory")
        const vramMax = maximum("gpu_memory")

        // Windows by desktop file and by pid
        const W = TaskManager.AbstractTasksModel
        const windowById = {}, windowByPid = {}
        const allWindows = []
        for (let w = 0; w < windows.rowCount(); w++) {
            const i = windows.index(w, 0)
            if (!windows.data(i, W.IsWindow)) continue
            const appId = windows.data(i, W.AppId) ?? ""
            const pid = windows.data(i, W.AppPid)
            allWindows.push({ row: w, appId: appId, pid: pid })
            if (appId && !(appId in windowById)) windowById[appId] = w
            if (pid && !(pid in windowByPid)) windowByPid[pid] = { row: w, appId: appId }
        }

        // Adds a row's pids and readings to another's
        const merge = (into, t) => {
            into.pids = into.pids.concat(t.pids)
            for (const k of ["cpu", "gpu", "vram", "ram", "disk"]) into[k] += t[k]
            into.windowRow = Math.max(into.windowRow, t.windowRow)
            t.merged = true
        }

        let list = []
        for (let r = 0; r < apps.rowCount(); r++) {
            const pids = apps.data(apps.index(r, 0), Process.ProcessDataModel.PIDs)
            if (!pids || !pids.length) continue
            const menuId = value(r, "menuId") || ""
            const appName = value(r, "appName") || menuId
            const unit = Object.keys(taskServices).find(u => appName.endsWith("/" + u))
            const service = unit ? taskServices[unit] : null
            const name = service ? service.name : appName
            const t = {
                key: menuId || name, name: name, icon: service ? service.icon : value(r, "iconName") || "",
                menuId: menuId, service: !!service,
                pids: Array.from(pids),
                cpu: (value(r, "usage") || 0) / cpuMax * 100,
                gpu: value(r, "gpu_usage") || 0,
                vram: value(r, "gpu_memory") || 0,
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

        // Load and its lead column, smoothed per key
        const loads = {}
        for (const t of list) {
            t.vramPercent = vramMax ? t.vram / vramMax * 100 : 0
            t.ramPercent = ramMax ? t.ram / ramMax * 100 : 0
            const shares = { cpu: t.cpu, gpu: t.gpu, vram: t.vramPercent, ram: t.ramPercent,
                             disk: t.disk / diskCeiling * 100 }
            t.lead = Object.keys(shares).reduce((a, b) => shares[b] > shares[a] ? b : a)
            const previous = taskLoads[t.key]
            t.load = previous === undefined ? shares[t.lead] : previous * 0.6 + shares[t.lead] * 0.4
            loads[t.key] = t.load
        }
        taskLoads = loads

        // One flat list; apps without a window have their name muted
        const byName = (a, b) => a.name.localeCompare(b.name)
        const order = sortKey === "name" ? byName : (a, b) => (b[sortKey] - a[sortKey]) || byName(a, b)
        let rows
        if (tasksFrozen && !sortNow && taskRows.count) {
            const was = {}
            for (let i = 0; i < taskRows.count; i++) was[taskRows.get(i).key] = i
            const known = list.filter(t => t.key in was).sort((a, b) => was[a.key] - was[b.key])
            rows = known.concat(list.filter(t => !(t.key in was)).sort(order))
        } else {
            rows = list.sort(order)
        }
        sortNow = false

        const current = taskIndex < taskRows.count ? taskRows.get(taskIndex) : null
        const currentKey = current ? current.key : ""
        const sameRows = rows.length === taskRows.count && rows.every((t, i) => taskRows.get(i).key === t.key)
        if (!sameRows) taskRows.clear()
        const pids = {}, windowRows = {}
        rows.forEach((t, i) => {
            pids[t.key] = t.pids
            windowRows[t.key] = allWindows.filter(w => (t.menuId && w.appId === t.menuId) || t.pids.includes(w.pid))
                                          .map(w => w.row)
            // The lead is only drawn when sorting by load and something is happening
            const row = { key: t.key, name: t.name, icon: t.icon, cpu: t.cpu, gpu: t.gpu,
                          vram: t.vram, vramPercent: t.vramPercent, ram: t.ram,
                          ramPercent: t.ramPercent, disk: t.disk, windowRow: t.windowRow,
                          lead: sortKey === "load" && t.load >= 1 ? t.lead : "" }
            if (sameRows) taskRows.set(i, row)
            else taskRows.append(row)
        })
        taskPids = pids
        taskWindows = windowRows
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

    // The first ask closes the app's windows like their × (the app can ask to
    // save and quit normally), or is SIGTERM for an app without one; asking
    // again within 5s, while it's still listed, is SIGKILL
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
            const rows = taskWindows[key] ?? []
            if (rows.length) rows.forEach(row => windows.requestClose(windows.makeModelIndex(row)))
            else processes.sendSignal(taskPids[key], Process.Signal.TerminateSignal)
            endingKey = key
            endingTimer.restart()
        }
    }

    // Usage colors as in the perf meter: warning from 70%, critical from 85%
    function levelColor(percent) {
        if (percent >= 85) return Theme.critical
        if (percent >= 70) return Theme.warning
        return Theme.text
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
        { icon: "mingcute-lock-fill",       label: "Lock",           run: () => session.lock() },
        { icon: "mingcute-power-fill",      label: "Power Off",      confirm: "Press again", run: () => session.requestShutdown(skipPrompt) },
        { icon: "mingcute-refresh-1-fill",  label: "Restart",        confirm: "Press again", run: () => session.requestReboot(skipPrompt) },
        { icon: "mingcute-moon-fill",       label: "Sleep",          run: () => session.suspend() },
        { icon: "leaves-log-out",           label: "Log Out",        confirm: "Press again", run: () => session.requestLogout(skipPrompt) },
        { icon: "mingcute-settings-6-fill", label: "System Settings", run: () => KCMUtils.KCMLauncher.openSystemSettings("") },
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

    // Opening and closing are animated by KWin (kwin-effects/leaves-popups): the
    // window drops out of the bar like the bar's popups
    function toggle() {
        if (launcher.visible) close()
        else open()
    }

    function open() {
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
    }

    function close() {
        if (!launcher.visible) return
        taskLinger.restart()
        launcher.visible = false
    }

    // ── Window ────────────────────────────────────────────────────────────

    // Drawn like the terminal launcher (agents/launcher): one flat surface, everything in
    // mono, lines only between the three areas and inside the task table
    PlasmaCore.Window {
        id: launcher
        visible: false
        // Layer surfaces need a real size up front (0 is a protocol error).
        // Tasks (750), search (~540), session (210), with 24px gaps around the rules
        width: 1630
        height: 660
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

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                anchors.topMargin: 18
                spacing: root.columnGap

                // Left: task manager. Column names, the machine's totals, then the apps
                ColumnLayout {
                    Layout.preferredWidth: root.taskWidth
                    Layout.maximumWidth: root.taskWidth
                    Layout.fillHeight: true
                    spacing: 0

                    HoverHandler { id: taskHover }

                    // Column names; click one to sort by it. "Tasks" sorts by name, and again back to load
                    Item {
                        id: taskHeader
                        Layout.fillWidth: true
                        implicitHeight: 30

                        MonoCaps {
                            height: parent.height
                            text: root.sortKey === "load" ? "Tasks · by load" : "Tasks"
                            color: root.area === "tasks" || root.sortKey === "name" || tasksTitleHover.hovered
                                   ? Theme.text : Theme.textMuted
                            TapHandler { onTapped: root.sortKey = root.sortKey === "name" ? "load" : "name" }
                            HoverHandler { id: tasksTitleHover; cursorShape: Qt.PointingHandCursor }
                            PlasmaComponents.ToolTip {
                                text: "Load: each app's largest share of CPU, GPU, memory or disk"
                                visible: tasksTitleHover.hovered && root.sortKey === "load"
                            }
                        }
                        RowLayout {
                            spacing: 0
                            height: parent.height
                            anchors { right: parent.right; rightMargin: 8 }
                            Repeater {
                                model: root.taskColumns
                                TaskHeader {}
                            }
                        }
                        Rule { anchors.bottom: parent.bottom; width: parent.width }
                    }

                    // The machine's totals: used / available on one line, the last two minutes under it
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: totalsRow.implicitHeight + 26

                        MonoCaps { y: 13; text: "System" }
                        RowLayout {
                            id: totalsRow
                            y: 12
                            spacing: 0
                            anchors { right: parent.right; rightMargin: 8 }
                            TotalCell {
                                column: "cpu"
                                used: Math.round(cpuTotal.value ?? 0) + "%"
                                of: " of " + (cpuThreads.value ?? "")
                                level: cpuTotal.value ?? 0
                                values: root.history.cpu
                                tip: "CPU: " + used + " of " + (cpuThreads.value ?? "?") + " threads"
                            }
                            TotalCell {
                                column: "gpu"
                                used: "N " + Math.round(nvidiaTotal.value ?? 0) + "%"
                                of: " · I " + Math.round(intelTotal.value ?? 0) + "%"
                                level: Math.max(nvidiaTotal.value ?? 0, intelTotal.value ?? 0)
                                values: root.history.gpu
                                tip: "GPU: NVIDIA " + Math.round(nvidiaTotal.value ?? 0) + "% · Intel "
                                     + Math.round(intelTotal.value ?? 0) + "% (history: the busier one)"
                            }
                            TotalCell {
                                column: "vram"
                                used: root.formatMemory((vramUsed.value ?? 0) / 1024)
                                of: " / " + root.formatMemory((vramTotal.value ?? 0) / 1024)
                                level: vramTotal.value ? vramUsed.value / vramTotal.value * 100 : 0
                                values: root.history.vram
                                tip: "NVIDIA video memory: " + used + of
                            }
                            TotalCell {
                                column: "ram"
                                used: root.formatMemory((ramUsed.value ?? 0) / 1024)
                                of: " / " + root.formatMemory((ramTotal.value ?? 0) / 1024)
                                level: ramTotal.value ? ramUsed.value / ramTotal.value * 100 : 0
                                values: root.history.ram
                                tip: "Memory: " + used + of
                            }
                            TotalCell {
                                column: "disk"
                                // A rate has no "available": its history scales to its own peak
                                used: root.formatRate((diskRead.value ?? 0) + (diskWrite.value ?? 0))
                                of: "/s"
                                values: root.history.disk
                                percent: false
                                tip: "Disk: read " + root.formatRate(diskRead.value ?? 0) + "/s · write "
                                     + root.formatRate(diskWrite.value ?? 0) + "/s"
                            }
                        }
                        Rule { anchors.bottom: parent.bottom; width: parent.width }
                    }

                    ListView {
                        id: taskList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        topMargin: 6
                        clip: true
                        model: taskRows
                        currentIndex: root.taskIndex
                        boundsBehavior: Flickable.StopAtBounds
                        highlightMoveDuration: 0
                        keyNavigationEnabled: false
                        delegate: TaskRow {}

                        layer.enabled: !atYBeginning || !atYEnd
                        layer.effect: GE.OpacityMask { maskSource: taskFadeMask }

                        Mono {
                            anchors.centerIn: parent
                            visible: taskList.count === 0
                            color: Theme.textMuted
                            text: apps.available ? "" : "Needs systemd app cgroups"
                        }
                    }
                }

                Rule { vertical: true }

                // Middle: the prompt, the folder path while navigating, and the list
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 42
                        color: "transparent"
                        radius: 3
                        border.width: 1
                        border.color: root.area === "search" ? Theme.accent : Theme.border
                        Behavior on border.color {
                            ColorAnimation { duration: root.hoverDuration; easing.type: root.houseCurve }
                        }

                        Mono {
                            id: caret
                            x: root.iconX + 10 - width / 2   // centered over the icons below
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: Theme.accent
                            text: "›"
                        }

                        TextInput {
                            id: search
                            anchors {
                                left: parent.left; leftMargin: root.nameX
                                right: modeTag.visible ? modeTag.left : parent.right; rightMargin: 12
                                verticalCenter: parent.verticalCenter
                            }
                            color: Theme.text
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.textOnAccent
                            font.family: root.mono
                            font.pixelSize: 14
                            clip: true
                            // A block at the end of the text, a bar inside it (so it hides no letter)
                            cursorDelegate: Rectangle {
                                width: search.cursorPosition < search.text.length ? 2 : 8
                                height: search.cursorRectangle.height
                                color: Theme.accent
                                visible: search.cursorVisible
                            }
                            property string lastText: ""
                            onTextChanged: {
                                root.area = "search"
                                const was = lastText
                                lastText = text
                                if (text === "/" && was === "") text = "~/"
                                else if (text === "~" && was === "~/") text = root.homePath
                            }

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 12   // after the block cursor
                                visible: !search.text
                                verticalAlignment: Text.AlignVCenter
                                text: "search apps and files, or / for folders"
                                color: Theme.textFaint
                                font: search.font
                            }

                            Keys.onPressed: event => root.handleKey(event)
                        }

                        // The mode, inverted like the terminal launcher's provider chip
                        Rectangle {
                            id: modeTag
                            visible: root.navigating
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            width: modeLabel.implicitWidth + 16
                            height: 22
                            radius: 2
                            color: Theme.accent
                            Mono {
                                id: modeLabel
                                anchors.centerIn: parent
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Theme.textOnAccent
                                text: "folders"
                            }
                        }
                    }

                    // The folder being listed, one crumb per folder (click one to go there)
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: root.navigating ? 36 : 10

                        Row {
                            visible: root.navigating
                            x: root.nameX
                            anchors.verticalCenter: parent.verticalCenter
                            Repeater {
                                model: root.navCrumbs
                                Row {
                                    required property var modelData
                                    Mono {
                                        font.pixelSize: 12
                                        color: crumbHover.hovered ? Theme.accent : Theme.textSoft
                                        text: modelData.name
                                        HoverHandler { id: crumbHover; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: search.text = modelData.path }
                                    }
                                    Mono {
                                        visible: modelData.name !== "/"
                                        font.pixelSize: 12
                                        color: Theme.textFaint
                                        text: "/"
                                    }
                                }
                            }
                        }
                        Mono {
                            visible: root.navigating && folder.status === FolderListModel.Ready
                            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                            font.pixelSize: 12
                            color: Theme.textFaint
                            text: root.navFilter ? root.navEntries.length + " of " + folder.count + " match “" + root.navFilter + "”"
                                                 : folder.count + (folder.count === 1 ? " item" : " items")
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

                        Mono {
                            anchors.centerIn: parent
                            visible: list.count === 0
                            color: Theme.textMuted
                            text: root.navigating ? (folder.status !== FolderListModel.Ready ? ""
                                                     : root.navFilter ? "No matches" : "Empty folder")
                                : root.searching ? (runner.querying ? "" : "No results") : "No recent apps yet"
                        }
                    }
                }

                Rule { vertical: true }

                // Right: power & session, then settings and the user
                ColumnLayout {
                    Layout.preferredWidth: root.sideWidth
                    Layout.maximumWidth: root.sideWidth
                    Layout.fillHeight: true
                    spacing: 0

                    Item { implicitHeight: 6 }   // first row's middle level with the prompt's
                    Repeater {
                        model: root.dividerAfter + 1
                        SideRow { required property int index; actionIndex: index }
                    }
                    Item { implicitHeight: 16 }
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
        const shift = event.modifiers & Qt.ShiftModifier
        const arrows = [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down]
        // Alt+1-5 sort the tasks by a column (again: back to load), from any area
        if (alt && event.key >= Qt.Key_1 && event.key <= Qt.Key_5) {
            sortBy(taskColumns[event.key - Qt.Key_1].key)
            event.accepted = true
            return
        }
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
                if (list.count) { area = "list"; list.currentIndex = autoHighlight ? Math.min(1, list.count - 1) : 0 }
            }
            else list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1)
            break
        case Qt.Key_Up:
            if (area === "tasks") taskIndex = Math.max(taskIndex - 1, 0)
            else if (area === "side") sideIndex = Math.max(sideIndex - 1, 0)
            else if (area === "list") {
                if (list.currentIndex <= (autoHighlight ? 1 : 0)) { area = "search"; list.currentIndex = 0 }
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
            else if (shift) showInFileManager()
            else if (area === "list" || !(navigating && navFilter === "")) run(entries[list.currentIndex])
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
        const highlighted = area === "list" || (area === "search" && autoHighlight)
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

    // Mono text, the launcher's one face (JetBrains Mono, as in the terminal launcher)
    component Mono: Text {
        font.family: root.mono
        font.pixelSize: 13
        color: Theme.text
        verticalAlignment: Text.AlignVCenter
    }

    // A caps label in mono: headings and column names
    component MonoCaps: Mono {
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.9
        color: Theme.textMuted
    }

    // A 1px line: between the three areas (vertical) and inside the task table
    component Rule: Rectangle {
        property bool vertical
        color: Theme.border
        implicitWidth: 1
        implicitHeight: 1
        Layout.fillHeight: vertical
        Layout.preferredWidth: vertical ? 1 : -1
    }

    // A row: the keyboard highlight is the one accented thing (amber at opacity.selection),
    // hover a neutral tint; no line under it
    component RowBackground: Rectangle {
        property bool selected
        property bool hovered
        property color tint: Theme.accent
        radius: 3
        color: selected ? Qt.rgba(tint.r, tint.g, tint.b, Theme.opacitySelection)
             : hovered ? Theme.hoverTint
             : "transparent"
        Behavior on color {
            ColorAnimation { duration: root.hoverDuration; easing.type: root.houseCurve }
        }
    }

    // The last two minutes of a total: a thin line over a faint fill, newest at the right.
    // Percentages are drawn 0-100; a rate (disk) against its own peak
    component History: Canvas {
        property var values: []
        property bool percent: true
        property color tone: Theme.text
        implicitWidth: root.taskCellWidth - 12
        implicitHeight: 22
        onValuesChanged: requestPaint()
        onToneChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const v = values
            if (!v || v.length < 2) return
            const max = percent ? 100 : Math.max(1024, ...v) * 1.15
            const n = root.historyLength
            const x = i => (n - v.length + i) / (n - 1) * width
            const y = value => height - 1 - Math.min(value, max) / max * (height - 2)
            ctx.beginPath()
            ctx.moveTo(x(0), height)
            v.forEach((value, i) => ctx.lineTo(x(i), y(value)))
            ctx.lineTo(x(v.length - 1), height)
            ctx.closePath()
            ctx.globalAlpha = 0.12
            ctx.fillStyle = tone
            ctx.fill()
            ctx.globalAlpha = 1
            ctx.beginPath()
            v.forEach((value, i) => i ? ctx.lineTo(x(i), y(value)) : ctx.moveTo(x(i), y(value)))
            ctx.strokeStyle = tone
            ctx.lineWidth = 1.2
            ctx.lineJoin = "round"
            ctx.stroke()
        }
    }

    component EntryRow: Item {
        id: entryRow
        required property var modelData
        required property int index
        readonly property bool pinned: root.isPinned(modelData)
        readonly property bool hasHeader: modelData.above !== ""
        // A group's heading ("Pinned 6", "Files 3"): a caps label and a faint count, with
        // space above it when it isn't the first
        readonly property int aboveHeight: !hasHeader ? 0 : index > 0 ? 38 : 28

        width: ListView.view.width
        height: aboveHeight + rowBackground.height

        Row {
            visible: entryRow.hasHeader
            x: root.nameX
            y: entryRow.aboveHeight - 28
            height: 28
            spacing: 10
            MonoCaps { height: parent.height; text: entryRow.modelData.above }
            Mono {
                height: parent.height
                font.pixelSize: 11
                color: Theme.textFaint
                text: entryRow.modelData.count ?? ""
            }
        }

        RowBackground {
            id: rowBackground
            y: entryRow.aboveHeight
            width: parent.width
            height: entryRow.modelData.subtitle ? root.twoLineRowHeight : root.rowHeight
            hovered: mouse.containsMouse
            // While typing, the first result is highlighted so Enter runs it
            selected: entryRow.index === list.currentIndex
                      && (root.area === "list" || (root.area === "search" && root.autoHighlight))

            Kirigami.Icon {
                id: appIcon
                x: root.iconX
                anchors.verticalCenter: parent.verticalCenter
                width: 20; height: 20
                source: entryRow.modelData.icon
            }

            Column {
                anchors { left: parent.left; leftMargin: root.nameX; right: pinIcon.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 3
                Mono {
                    width: parent.width
                    elide: Text.ElideRight
                    text: entryRow.modelData.name
                }
                Mono {
                    visible: text !== ""
                    width: parent.width
                    elide: Text.ElideMiddle  // paths: keep the start and the file's folder
                    font.pixelSize: 11
                    color: Theme.textMuted
                    text: entryRow.modelData.subtitle
                }
            }

            // Pin indicator at the end: always shown when pinned, faint on hover otherwise
            Kirigami.Icon {
                id: pinIcon
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                width: 14; height: 14
                source: "mingcute-pin-fill"
                isMask: true
                visible: entryRow.modelData.favoriteId !== ""
                color: Theme.text
                opacity: entryRow.pinned || pinMouse.containsMouse ? 0.6 : mouse.containsMouse ? 0.25 : 0
                Behavior on opacity {
                    NumberAnimation { duration: root.hoverDuration; easing.type: root.houseCurve }
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

    // A column name; the sorted column is drawn in the text color
    component TaskHeader: Item {
        id: header
        required property var modelData
        required property int index
        readonly property bool active: root.sortKey === modelData.key
        Layout.preferredWidth: root.columnWidth(modelData.key)
        Layout.fillHeight: true

        MonoCaps {
            anchors.right: parent.right
            height: parent.height
            text: header.modelData.short
            color: header.active || headerHover.hovered ? Theme.text : Theme.textMuted
            Behavior on color {
                ColorAnimation { duration: root.hoverDuration; easing.type: root.houseCurve }
            }
        }
        HoverHandler { id: headerHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.sortBy(header.modelData.key) }
        PlasmaComponents.ToolTip {
            text: header.modelData.label + " (Alt+" + (header.index + 1) + ")"
            visible: headerHover.hovered
        }
    }

    // A right-aligned reading; idle ones (nothing happening) are faint, and when sorting
    // by load the cells other than the row's lead are muted
    component TaskCell: Mono {
        property string column
        property string lead
        property real level
        property bool idle
        Layout.preferredWidth: root.columnWidth(column)
        horizontalAlignment: Text.AlignRight
        font.pixelSize: 12
        color: idle ? Theme.textFaint
             : level >= 70 || lead === "" || lead === column ? root.levelColor(level)
             : Theme.textMuted
    }

    // A total: used / available on one line (available faint), its history under it
    component TotalCell: Item {
        id: totalCell
        property string used
        property string of
        property real level
        property string tip
        property var values: []
        property bool percent: true
        property string column
        Layout.preferredWidth: root.columnWidth(column)
        implicitHeight: totalColumn.implicitHeight

        Column {
            id: totalColumn
            anchors.right: parent.right
            spacing: 8
            Row {
                anchors.right: parent.right
                Mono { font.pixelSize: 12; color: root.levelColor(totalCell.level); text: totalCell.used }
                Mono { font.pixelSize: 12; color: Theme.textFaint; text: totalCell.of }
            }
            History {
                anchors.right: parent.right
                values: totalCell.values
                percent: totalCell.percent
                tone: root.levelColor(totalCell.level)
            }
        }
        HoverHandler { id: totalHover }
        PlasmaComponents.ToolTip { text: totalCell.tip; visible: totalHover.hovered }
    }

    component TaskRow: Item {
        id: taskRow
        required property int index
        required property string key
        required property string name
        required property string icon
        required property real cpu
        required property real gpu
        required property real vram
        required property real vramPercent
        required property real ram
        required property real ramPercent
        required property real disk
        required property int windowRow
        required property string lead
        readonly property bool ending: root.endingKey === key
        readonly property bool hovered: taskMouse.containsMouse || endMouse.containsMouse

        width: ListView.view.width
        height: root.taskRowHeight

        RowBackground {
            width: parent.width
            height: root.taskRowHeight
            hovered: taskRow.hovered
            selected: (root.area === "tasks" && root.taskIndex === taskRow.index) || taskRow.ending
            tint: taskRow.ending ? Theme.critical : Theme.accent

            Kirigami.Icon {
                id: taskIcon
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 20; height: 20
                source: taskRow.icon || "application-x-executable"
            }

            // Background apps (no window) in the muted color
            Mono {
                anchors {
                    left: taskIcon.right; leftMargin: 12
                    right: cells.left; rightMargin: taskRow.hovered ? 28 : 4
                    verticalCenter: parent.verticalCenter
                }
                elide: Text.ElideRight
                color: taskRow.ending ? Theme.critical
                     : taskRow.windowRow >= 0 ? Theme.text : Theme.textMuted
                text: taskRow.ending ? "Again to force quit" : taskRow.name
            }

            // End task, shown on hover
            Kirigami.Icon {
                id: endIcon
                anchors { right: cells.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: 14; height: 14
                source: "mingcute-close-fill"
                isMask: true
                color: endMouse.containsMouse ? Theme.critical : Theme.text
                opacity: endMouse.containsMouse ? 1 : taskRow.hovered ? 0.5 : 0
                Behavior on opacity {
                    NumberAnimation { duration: root.hoverDuration; easing.type: root.houseCurve }
                }
            }

            RowLayout {
                id: cells
                spacing: 0
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                TaskCell { column: "cpu"; lead: taskRow.lead; text: Math.round(taskRow.cpu) + "%"; level: taskRow.cpu; idle: taskRow.cpu < 0.5 }
                TaskCell { column: "gpu"; lead: taskRow.lead; text: Math.round(taskRow.gpu) + "%"; level: taskRow.gpu; idle: taskRow.gpu < 0.5 }
                TaskCell { column: "vram"; lead: taskRow.lead; text: root.formatMemory(taskRow.vram); level: taskRow.vramPercent; idle: taskRow.vram < 512 }
                TaskCell { column: "ram"; lead: taskRow.lead; text: root.formatMemory(taskRow.ram); level: taskRow.ramPercent }
                TaskCell { column: "disk"; lead: taskRow.lead; text: root.formatRate(taskRow.disk); idle: taskRow.disk < 512 }
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

    // Power and session as rows with their icons; the keyboard's place is highlighted,
    // and a row that asks to be pressed again turns critical
    component SideRow: RowBackground {
        id: sideRow
        property int actionIndex
        readonly property var sideAction: root.sideActions[actionIndex]
        readonly property bool confirming: root.confirmIndex === actionIndex

        Layout.fillWidth: true
        implicitHeight: sideAction.user ? 40 : root.rowHeight
        selected: (root.area === "side" && root.sideIndex === actionIndex) || confirming
        hovered: sideMouse.containsMouse
        tint: confirming ? Theme.critical : Theme.accent

        RowLayout {
            anchors { fill: parent; leftMargin: root.iconX; rightMargin: 8 }
            spacing: 12

            KirigamiComponents.Avatar {
                visible: !!sideRow.sideAction.user
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                name: sideRow.sideAction.label
                source: user.faceIconUrl
                cache: false
            }
            Kirigami.Icon {
                visible: !sideRow.sideAction.user
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                source: sideRow.sideAction.icon ?? ""
                isMask: true
                color: sideRow.confirming ? Theme.critical : Theme.text
            }
            Mono {
                Layout.fillWidth: true
                elide: Text.ElideRight
                color: sideRow.confirming ? Theme.critical : sideRow.sideAction.user ? Theme.textMuted : Theme.text
                text: sideRow.confirming ? sideRow.sideAction.confirm : sideRow.sideAction.label
            }
        }
        MouseArea {
            id: sideMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.runSide(sideRow.actionIndex)
        }
    }
}
