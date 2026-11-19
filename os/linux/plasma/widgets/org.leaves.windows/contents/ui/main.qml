// The bar's window strip: this monitor's layout and its windows.
//
//   ▭▭  │ 🗔 🗔 │ 🗔 🗔 🗔
//   │     │       └ the windows behind, most recent first, minimized ones last (dimmed)
//   │     └ the windows in the columns, left to right (a divider after them)
//   └ the layout glyph: hovering opens the picker (no layout, 2 or 3 columns)
//
// One icon per window on a flat key; the focused one's key is held down. Hovering an
// icon opens a live preview (switching at once between icons); a click focuses
// the window (minimizes it if it's already focused), a middle click closes it,
// the wheel steps focus along the strip.
//
// The layout and columns come from the leaves-windows KWin script, which writes
// them into this widget's "state" setting; a layout is picked through its
// keyless "Leaves Layout <monitor> <n>" shortcuts (kwin/leaves-windows).
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.pipewire as PipeWire
import Levves

import "../../../../../leaves"

PlasmoidItem {
    id: root

    // DESIGN.md motion and spacing
    readonly property int houseCurve: Easing.OutQuint
    readonly property int hoverDuration: Theme.durationHover
    readonly property int iconSize: 16
    readonly property int cellWidth: 28
    readonly property int leadingGap: 12  // after the launcher icon, like the perf meter's edge margin
    readonly property int dividerGap: Theme.space8
    readonly property int pad: Theme.space12  // popup content to its frame (16 with the style's 4)
    readonly property int popupGap: Theme.space4  // bar popups float this far off the bar
    readonly property int thumbWidth: 256
    readonly property int thumbHeight: 160

    // Hover popups have no tooltips (TODO.md Top bar)
    toolTipMainText: ""
    toolTipSubText: ""
    preferredRepresentation: fullRepresentation

    // ── State ─────────────────────────────────────────────────────────────

    property string screenName: ""
    readonly property var monitorState: {
        try {
            return JSON.parse(Plasmoid.configuration.state)[screenName] || null
        } catch (e) {
            return null
        }
    }
    readonly property int columns: monitorState ? monitorState.columns : 1
    readonly property var columnIds: monitorState ? monitorState.windows : []
    onColumnIdsChanged: Qt.callLater(rebuild)

    TaskManager.VirtualDesktopInfo { id: desktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }
    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortLastActivated
        filterByScreen: true
        screenGeometry: Plasmoid.containment.screenGeometry
        filterByVirtualDesktop: true
        virtualDesktop: desktopInfo.currentDesktop
        filterByActivity: true
        activity: activityInfo.currentActivity
    }
    Connections {
        target: tasks
        function onDataChanged() { Qt.callLater(root.rebuild) }
        function onRowsInserted() { Qt.callLater(root.rebuild) }
        function onRowsRemoved() { Qt.callLater(root.rebuild) }
        function onRowsMoved() { Qt.callLater(root.rebuild) }
        function onModelReset() { Qt.callLater(root.rebuild) }
        function onLayoutChanged() { Qt.callLater(root.rebuild) }
    }

    // The strip, in order: {wid, divider} rows, kept in place (moved, not
    // recreated) so an icon under the pointer stays hovered as the order changes
    ListModel { id: strip }
    // wid -> {row, rawId, title, icon, active, minimized, last, geometry}
    property var windowsById: ({})

    function normalized(id) {
        return String(id).replace(/[{}]/g, "").toLowerCase()
    }

    function time(d) {
        return d ? new Date(d).getTime() || 0 : 0
    }

    function rebuild() {
        const R = TaskManager.AbstractTasksModel
        const all = []
        for (let row = 0; row < tasks.count; row++) {
            const i = tasks.makeModelIndex(row)
            if (!tasks.data(i, R.IsWindow))
                continue
            const ids = tasks.data(i, R.WinIdList)
            const rawId = ids && ids.length ? String(ids[0]) : ""
            all.push({
                row: row,
                rawId: rawId,
                wid: normalized(rawId),
                title: tasks.data(i, Qt.DisplayRole) || "",
                icon: tasks.data(i, Qt.DecorationRole),
                active: !!tasks.data(i, R.IsActive),
                minimized: !!tasks.data(i, R.IsMinimized),
                last: time(tasks.data(i, R.LastActivated)),
                geometry: tasks.data(i, R.Geometry),
            })
        }
        // A window spanning columns is listed once
        const tiled = columnIds.map(id => all.find(w => w.wid === id))
                               .filter((w, i, list) => w && list.indexOf(w) === i)
        const rest = all.filter(w => tiled.indexOf(w) === -1)
                        .sort((a, b) => (a.minimized - b.minimized) || (b.last - a.last))
        const order = tiled.concat(rest)

        const byId = {}
        order.forEach(w => byId[w.wid] = w)
        windowsById = byId

        // Sync the strip: move rows into place, add new ones, drop the rest
        order.forEach((w, i) => {
            const divider = tiled.length > 0 && i === tiled.length
            let j = i
            while (j < strip.count && strip.get(j).wid !== w.wid)
                j++
            if (j === strip.count)
                strip.insert(i, { wid: w.wid, divider: divider })
            else {
                if (j !== i)
                    strip.move(j, i, 1)
                if (strip.get(i).divider !== divider)
                    strip.setProperty(i, "divider", divider)
            }
        })
        if (strip.count > order.length)
            strip.remove(order.length, strip.count - order.length)
    }

    // ── Actions ───────────────────────────────────────────────────────────

    function modelIndex(w) {
        return tasks.makeModelIndex(w.row)
    }

    function focusOrMinimize(w) {
        if (w.active)
            tasks.requestToggleMinimized(modelIndex(w))
        else
            tasks.requestActivate(modelIndex(w))
    }

    function closeWindow(w) {
        tasks.requestClose(modelIndex(w))
    }

    // The wheel: the next or previous window along the strip (minimized ones skipped)
    function step(delta) {
        const list = []
        for (let i = 0; i < strip.count; i++) {
            const w = windowsById[strip.get(i).wid]
            if (w && !w.minimized)
                list.push(w)
        }
        if (!list.length)
            return
        const current = list.findIndex(w => w.active)
        const next = current === -1 ? 0 : (current + delta + list.length) % list.length
        tasks.requestActivate(modelIndex(list[next]))
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        onNewData: source => disconnectSource(source)
    }

    function applyLayout(count) {
        if (!/^[A-Za-z0-9_-]+$/.test(screenName))
            return
        executable.connectSource("qdbus-qt6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Leaves Layout "
                                 + screenName + " " + count + "'")
    }

    // ── Bar ───────────────────────────────────────────────────────────────

    // The icon under the pointer and the window whose preview is showing
    property Item hoveredCell: null
    property string previewId: ""
    property Item previewCell: null
    readonly property var previewWindow: windowsById[previewId] || null

    function setHovered(cell, hovered) {
        if (hovered)
            hoveredCell = cell
        else if (hoveredCell === cell)
            hoveredCell = null
    }

    function showPreview(cell) {
        previewId = cell.wid
        previewCell = cell
        preview.visible = true
    }

    onHoveredCellChanged: {
        if (hoveredCell && preview.visible)
            showPreview(hoveredCell)
    }
    onPreviewWindowChanged: if (!previewWindow) preview.visible = false

    HoverOpener {
        id: previewOpener
        triggerHovered: root.hoveredCell !== null
        popupHovered: previewHover.hovered
        open: preview.visible
        onOpenRequested: if (root.hoveredCell) root.showPreview(root.hoveredCell)
        onCloseRequested: preview.visible = false
    }

    HoverOpener {
        id: pickerOpener
        popupHovered: pickerHover.hovered
        open: picker.visible
        onOpenRequested: picker.visible = true
        onCloseRequested: picker.visible = false
    }

    fullRepresentation: Item {
        id: bar

        Layout.minimumWidth: row.implicitWidth
        Layout.preferredWidth: row.implicitWidth
        Layout.maximumWidth: row.implicitWidth
        Layout.fillHeight: true

        Binding { target: root; property: "screenName"; value: bar.Screen.name }
        Binding { target: previewOpener; property: "bar"; value: bar.Window.window }
        Binding { target: pickerOpener; property: "bar"; value: bar.Window.window }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            property real pending: 0
            onWheel: event => {
                pending += event.angleDelta.y
                while (Math.abs(pending) >= 120) {
                    root.step(pending > 0 ? -1 : 1)
                    pending -= pending > 0 ? 120 : -120
                }
            }
        }

        Row {
            id: row
            height: parent.height

            Item {
                width: root.leadingGap
                height: 1
            }

            // The layout glyph; its picker opens on hover
            Item {
                id: glyphCell
                width: root.cellWidth
                height: parent.height

                Binding { target: pickerOpener; property: "triggerHovered"; value: glyphHover.hovered }
                Component.onCompleted: glyphAnchor.item = glyphCell
                HoverHandler { id: glyphHover }

                Key {
                    anchors.centerIn: parent
                    width: root.cellWidth - 4
                    height: 22
                    flat: true
                    hoverEnabled: true
                    focusPolicy: Qt.NoFocus
                    contentItem: Item {
                        LayoutGlyph {
                            anchors.centerIn: parent
                            width: root.iconSize
                            height: 12
                            columns: root.columns
                            color: root.columns > 1 ? Theme.text : Theme.textMuted
                        }
                    }
                }

                ActiveLine { active: picker.visible }
            }

            Repeater {
                model: strip

                delegate: Item {
                    id: slot
                    required property string wid
                    required property bool divider
                    readonly property var window: root.windowsById[wid] || null

                    width: (divider ? 2 * root.dividerGap + 1 : 0) + root.cellWidth
                    height: row.height

                    Rectangle {
                        visible: slot.divider
                        x: root.dividerGap
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 12
                        color: Theme.border
                    }

                    Item {
                        id: cell
                        readonly property string wid: slot.wid
                        x: slot.divider ? 2 * root.dividerGap + 1 : 0
                        width: root.cellWidth
                        height: parent.height

                        HoverHandler {
                            id: cellHover
                            onHoveredChanged: root.setHovered(cell, hovered)
                        }
                        Component.onDestruction: root.setHovered(cell, false)

                        // A flat key, held down for the focused window
                        Key {
                            anchors.centerIn: parent
                            width: root.cellWidth - 4
                            height: 22
                            flat: true
                            focusPolicy: Qt.NoFocus
                            current: slot.window !== null && slot.window.active
                            onClicked: if (slot.window) root.focusOrMinimize(slot.window)
                            contentItem: Item {
                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: root.iconSize
                                    height: root.iconSize
                                    source: slot.window ? slot.window.icon : ""
                                    opacity: slot.window && slot.window.minimized ? 0.4 : 1
                                }
                            }
                            TapHandler {
                                acceptedButtons: Qt.MiddleButton
                                onTapped: if (slot.window) root.closeWindow(slot.window)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Popups ────────────────────────────────────────────────────────────

    // A window's live preview (its title under it); the icon stands in while
    // it's minimized or the stream hasn't started
    PlasmaCore.PopupPlasmaWindow {
        id: preview
        visualParent: root.previewCell
        popupDirection: Qt.BottomEdge
        floating: true
        margin: root.popupGap
        hideOnWindowDeactivate: true
        // The window doesn't follow its content's size by itself
        width: previewContent.implicitWidth + leftPadding + rightPadding
        height: previewContent.implicitHeight + topPadding + bottomPadding

        mainItem: Item {
            id: previewContent
            readonly property var window: root.previewWindow
            readonly property real aspect: window && window.geometry && window.geometry.height > 0
                ? window.geometry.width / window.geometry.height : root.thumbWidth / root.thumbHeight
            readonly property bool wide: aspect >= root.thumbWidth / root.thumbHeight
            readonly property int thumbW: wide ? root.thumbWidth : Math.round(root.thumbHeight * aspect)
            readonly property int thumbH: wide ? Math.round(root.thumbWidth / aspect) : root.thumbHeight

            implicitWidth: Math.max(thumbW, 160) + 2 * root.pad
            implicitHeight: root.pad + thumbH + 8 + title.implicitHeight + root.pad
            width: implicitWidth
            height: implicitHeight

            HoverHandler { id: previewHover }

            TaskManager.ScreencastingRequest {
                id: cast
                uuid: preview.visible && previewContent.window && !previewContent.window.minimized
                      ? previewContent.window.rawId : ""
            }

            Item {
                x: Math.round((parent.width - previewContent.thumbW) / 2)
                y: root.pad
                width: previewContent.thumbW
                height: previewContent.thumbH

                PipeWire.PipeWireSourceItem {
                    id: stream
                    anchors.fill: parent
                    nodeId: cast.nodeId
                    // Shown as soon as there's a stream: a hidden item never draws its first frame
                    visible: cast.nodeId > 0
                }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 48
                    height: 48
                    visible: !stream.visible || !stream.ready
                    source: previewContent.window ? previewContent.window.icon : ""
                }
            }

            Text {
                id: title
                x: root.pad
                y: root.pad + previewContent.thumbH + 8
                width: parent.width - 2 * root.pad
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.family: Theme.typeFamilyDisplay
                font.pixelSize: Theme.typeSizeTitle
                font.weight: Theme.typeWeightSemibold
                color: Theme.text
                text: previewContent.window ? previewContent.window.title : ""
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onClicked: mouse => {
                    const w = previewContent.window
                    if (!w)
                        return
                    if (mouse.button === Qt.MiddleButton)
                        root.closeWindow(w)
                    else
                        tasks.requestActivate(root.modelIndex(w))
                    preview.visible = false
                }
            }
        }
    }

    // The layout picker: no layout, two or three columns
    PlasmaCore.PopupPlasmaWindow {
        id: picker
        visualParent: glyphAnchor.item
        popupDirection: Qt.BottomEdge
        floating: true
        margin: root.popupGap
        hideOnWindowDeactivate: true
        width: pickerContent.implicitWidth + leftPadding + rightPadding
        height: pickerContent.implicitHeight + topPadding + bottomPadding

        mainItem: Item {
            id: pickerContent
            implicitWidth: options.implicitWidth + 2 * root.pad
            implicitHeight: options.implicitHeight + 2 * root.pad
            width: implicitWidth
            height: implicitHeight

            HoverHandler { id: pickerHover }

            Row {
                id: options
                x: root.pad
                y: root.pad
                spacing: 8

                Repeater {
                    model: [
                        { columns: 1, label: "Free" },
                        { columns: 2, label: "2 columns" },
                        { columns: 3, label: "3 columns" },
                    ]

                    delegate: Item {
                        id: option
                        required property var modelData
                        readonly property bool current: root.columns === modelData.columns
                        width: 80
                        height: 72

                        // A key per layout; the one in use is held down
                        Key {
                            anchors.fill: parent
                            focusPolicy: Qt.NoFocus
                            current: option.current
                            onClicked: {
                                root.applyLayout(option.modelData.columns)
                                picker.visible = false
                            }
                            contentItem: Item {
                                LayoutGlyph {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 10
                                    width: 48
                                    height: 30
                                    lineWidth: 2
                                    columns: option.modelData.columns
                                    color: option.current ? Theme.text : Theme.textMuted
                                }
                                Caps {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 10 + 30 + 8
                                    color: option.current ? Theme.text : Theme.textMuted
                                    text: option.modelData.label
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // The picker's anchor lives in the bar (fullRepresentation), out of reach by id
    QtObject {
        id: glyphAnchor
        property Item item: null
    }
}
