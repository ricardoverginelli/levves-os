// Centered launcher. Subtle icon in the bar; Super or a click opens a window
// centered on the active screen (layer shell, no anchors).
//
//   ┌ search ─────────────────┬ Lock ──────────┐
//   │ pinned apps (pin at end)│ Power Off      │
//   │ recent apps, newest     │ Restart        │
//   │ first — or search       │ Sleep          │
//   │ results while typing    │ Log Out        │
//   │                         │ ───            │
//   │                         │ System Settings│
//   │                         │ (user)         │
//   └─────────────────────────┴────────────────┘
//
// Keys: focus stays in the search field; arrows move a highlight between
// areas. Down = list, Right = side panel (from search only when the cursor is
// at the end), Left = back, Enter = run, Esc = close.
// Pins: Alt+Right pins, Alt+Left unpins, Alt+Up/Down reorders pinned apps
// (Ctrl+P toggles). Right-click a row (or click its pin) to pin/unpin it.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.components as KirigamiComponents
import org.kde.layershell as LayerShell
import org.kde.coreaddons as KCoreAddons
import org.kde.kcmutils as KCMUtils
import org.kde.plasma.private.kicker as Kicker
import org.kde.plasma.private.sessions as Sessions

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
    readonly property int sideWidth: 200

    // Pins survive the bar being rebuilt (new applet id), so the client id is fixed
    readonly property string pinsClient: "org.leaves.launcher.favorites"

    // Apps never listed in recents or search (System Settings has its own row
    // in the side panel). Pinning one still shows it.
    readonly property var hiddenApps: ["systemsettings.desktop", "org.kde.discover.desktop"]
    function isHidden(favoriteId) {
        return hiddenApps.includes(favoriteId.replace(/^applications:/, ""))
    }

    // Keyboard state: which area has the highlight
    property string area: "search"   // "search" | "list" | "side"
    property string areaBeforeSide: "search"
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
            source: "view-app-grid-symbolic"
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

    Kicker.RunnerModel {
        id: runner
        appletInterface: root
        favoritesModel: pins
        mergeResults: true
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
        id: searchRows
        model: runner.count > 0 ? runner.modelForRow(0) : null
        delegate: Row {}
        onObjectAdded: Qt.callLater(root.rebuildSearch)
        onObjectRemoved: Qt.callLater(root.rebuildSearch)
        onModelChanged: Qt.callLater(root.rebuildSearch)
    }
    Connections {
        target: pins
        function onFavoritesChanged() { Qt.callLater(root.rebuildHome) }
        function onRowsMoved() { Qt.callLater(root.rebuildHome) }
        function onModelReset() { Qt.callLater(root.rebuildHome) }
    }

    function entryFrom(row, source, i) {
        return { source: source, row: i, name: row.name, icon: row.icon,
                 description: row.description, favoriteId: row.favoriteId }
    }

    function rebuildHome() {
        const out = []
        // A pin can use a different id than its recent entry (preferred://browser
        // vs brave-browser.desktop), so names dedupe too
        const pinned = new Set()
        const add = (r, source, i) => {
            const e = entryFrom(r, source, i)
            e.description = ""  // home list shows names only
            out.push(e)
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
        for (let i = 0; i < searchRows.count; i++) {
            const r = searchRows.objectAt(i)
            if (r && !isHidden(r.favoriteId)) out.push(entryFrom(r, searchRows.model, i))
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

    // ── Power & session ───────────────────────────────────────────────────

    Sessions.SessionManagement { id: session }
    KCoreAddons.KUser { id: user }

    readonly property var sideActions: [
        { icon: "system-lock-screen", label: "Lock",      run: () => session.lock() },
        { icon: "system-shutdown",    label: "Power Off", run: () => session.requestShutdown() },
        { icon: "system-reboot",      label: "Restart",   run: () => session.requestReboot() },
        { icon: "system-suspend",     label: "Sleep",     run: () => session.suspend() },
        { icon: "system-log-out",     label: "Log Out",   run: () => session.requestLogout() },
        { icon: "configure",          label: "System Settings", run: () => KCMUtils.KCMLauncher.openSystemSettings("") },
        { user: true,                 label: user.fullName || user.loginName, run: () => KCMUtils.KCMLauncher.openSystemSettings("kcm_users") },
    ]
    readonly property int dividerAfter: 4  // line between Log Out and System Settings
    property int sideIndex: 0

    function runSide(i) {
        close()
        sideActions[i].run()
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
        rebuildHome()
        launcher.visible = true
        launcher.requestActivate()
        search.forceActiveFocus()
        openAnim.restart()
    }

    property bool closing: false
    function close() {
        if (!launcher.visible || closing) return
        closing = true
        openAnim.stop()
        closeAnim.restart()
    }

    // ── Window ────────────────────────────────────────────────────────────

    PlasmaCore.Window {
        id: launcher
        visible: false
        // Layer surfaces need a real size up front (0 is a protocol error)
        width: 680
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

                // Left: search + list
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
                        border.width: 1
                        border.color: root.area === "search" ? Qt.alpha(Kirigami.Theme.highlightColor, 0.6) : "transparent"
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
        }
    }

    // ── Keyboard ──────────────────────────────────────────────────────────

    function handleKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier
        if ((event.modifiers & Qt.AltModifier) && area !== "side" && handlePinKey(event.key)) {
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
            if (area === "side") sideIndex = Math.min(sideIndex + 1, sideActions.length - 1)
            else if (area === "search") {
                // While typing, row 0 is already highlighted, so Down goes to row 1
                if (list.count) { area = "list"; list.currentIndex = searching ? Math.min(1, list.count - 1) : 0 }
            }
            else list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1)
            break
        case Qt.Key_Up:
            if (area === "side") sideIndex = Math.max(sideIndex - 1, 0)
            else if (area === "list") {
                if (list.currentIndex <= (searching ? 1 : 0)) { area = "search"; list.currentIndex = 0 }
                else list.currentIndex--
            }
            break
        case Qt.Key_Right:
            if (area === "side") break
            if (area === "search" && search.cursorPosition < search.text.length) { event.accepted = false; return }
            areaBeforeSide = area
            area = "side"
            break
        case Qt.Key_Left:
            if (area === "side") area = areaBeforeSide
            else if (area === "search") { event.accepted = false; return }
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (area === "side") runSide(sideIndex)
            else run(entries[list.currentIndex])
            break
        case Qt.Key_P:
            if (!ctrl || area === "side") { event.accepted = false; return }
            togglePin(entries[list.currentIndex])
            break
        default:
            event.accepted = false
            return
        }
        event.accepted = true
        list.positionViewAtIndex(list.currentIndex, ListView.Contain)
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

    component RowBackground: Rectangle {
        property bool selected
        property bool hovered
        radius: 8
        color: selected ? Qt.alpha(Kirigami.Theme.highlightColor, 0.18)
             : hovered ? Qt.alpha(Kirigami.Theme.textColor, 0.08)
             : "transparent"
        Behavior on color {
            ColorAnimation { duration: root.hoverDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: root.houseCurve }
        }
    }

    component EntryRow: RowBackground {
        id: entryRow
        required property var modelData
        required property int index
        readonly property bool pinned: root.isPinned(modelData)

        width: ListView.view.width
        height: root.rowHeight
        hovered: mouse.containsMouse
        // While typing, the first result is highlighted so Enter runs it
        selected: index === list.currentIndex
                  && (root.area === "list" || (root.area === "search" && root.searching))

        Kirigami.Icon {
            id: appIcon
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 24; height: 24
            source: entryRow.modelData.icon
        }

        Text {
            anchors { left: appIcon.right; leftMargin: 12; right: pinIcon.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            elide: Text.ElideRight
            textFormat: Text.StyledText
            font.pointSize: 10
            color: Kirigami.Theme.textColor
            text: {
                const d = entryRow.modelData.description
                const muted = Kirigami.Theme.disabledTextColor
                return root.htmlEscaped(entryRow.modelData.name)
                    + (d && d !== entryRow.modelData.name ? `  <font color="${muted}">${root.htmlEscaped(d)}</font>` : "")
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

    component SideRow: RowBackground {
        id: sideRow
        property int actionIndex
        readonly property var action: root.sideActions[actionIndex]

        Layout.fillWidth: true
        implicitHeight: action.user ? 40 : 32
        hovered: sideMouse.containsMouse
        selected: root.area === "side" && root.sideIndex === actionIndex

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
            color: Kirigami.Theme.textColor
        }
        Text {
            anchors { left: (sideRow.action.user ? avatar : sideIcon).right; leftMargin: 12; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            elide: Text.ElideRight
            font.pointSize: 10
            color: Kirigami.Theme.textColor
            text: sideRow.action.label
        }
        MouseArea {
            id: sideMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.runSide(sideRow.actionIndex)
        }
    }

    function htmlEscaped(text) {
        return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;")
    }
}
