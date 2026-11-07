// KWin window switcher (Alt+Tab layout): a row of thumbnails of one monitor's
// windows, by last use with minimized windows at the end. It opens on the
// focused window's monitor; Up/Down switch the row (and the switcher itself)
// to the monitor above or below, Left/Right and Tab step along the row.
//
//          ┌──────────────────────────────┐
//          │ ┌────┐ ┌────┐ ┌────┐ ┌────┐  │   ↑ the monitor above
//          │ │ ▢  │ │ ▢  │ │ ▢  │ │ ▢  │  │   ← → along the row
//          │ └────┘ └────┘ └────┘ └────┘  │   ↓ the monitor below
//          └──────────────────────────────┘
//
// KWin keeps its own order (last use, every monitor) and steps through it on
// Tab; releasing Alt activates its current row. So the layout keeps `order`
// (shown position → KWin row) and turns each step KWin takes into a step along
// the shown order, writing the row there back to KWin. Arrows are handled here.
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin
import Levves

KWin.TabBoxSwitcher {
    id: tabBox

    // Levves motion and spacing (design/DESIGN.md)
    readonly property int houseCurve: Easing.OutQuint
    readonly property int hoverDuration: Theme.durationHover
    readonly property int pad: Theme.space12
    readonly property int thumbWidth: 240
    readonly property int thumbHeight: 150
    readonly property int captionHeight: 20
    readonly property int cellWidth: thumbWidth + 2 * 8
    readonly property int cellHeight: 8 + thumbHeight + 8 + captionHeight + 8

    property var output: null  // the monitor whose windows are shown
    readonly property rect area: output ? output.geometry : screenGeometry
    property var order: []    // shown position → KWin row
    property int pos: -1      // shown position of KWin's current row
    property int lastRow: -1  // KWin's current row as last seen, to tell which way it stepped
    property bool fresh: true // the row was just (re)filled: select its first window that isn't the focused one
    property bool syncing: false

    // The model's roles, readable by row (delegates only see their own)
    Instantiator {
        id: rows
        model: tabBox.model
        delegate: QtObject {
            readonly property var wid: model.windowId
            readonly property string caption: model.caption
            readonly property var icon: model.icon
            readonly property bool minimized: model.minimized
        }
        onObjectAdded: Qt.callLater(tabBox.resort)
        onObjectRemoved: Qt.callLater(tabBox.resort)
    }

    // Every row with its window's monitor, in KWin's order
    function items() {
        const byId = {}
        for (const w of KWin.Workspace.windows)
            byId[w.internalId.toString()] = w
        const list = []
        for (let row = 0; row < rows.count; row++) {
            const o = rows.objectAt(row)
            if (!o)
                return null
            const w = byId[o.wid ? o.wid.toString() : ""]
            list.push({ row: row, output: w ? w.output : null, minimized: o.minimized, focused: !!w && w === KWin.Workspace.activeWindow })
        }
        return list
    }

    function resort() {
        const all = items()
        if (!all || all.length == 0)
            return
        const has = o => all.some(i => i.output === o)
        if (!output || !has(output)) {
            const focused = KWin.Workspace.activeWindow
            output = focused && has(focused.output) ? focused.output
                   : has(KWin.Workspace.activeScreen) ? KWin.Workspace.activeScreen
                   : all[0].output
            fresh = true
        }
        const shown = all.filter(i => i.output === output)
        shown.sort((a, b) => a.minimized - b.minimized || a.row - b.row)
        order = shown.map(i => i.row)
        if (fresh) {
            fresh = false
            const first = shown.findIndex(i => !i.focused)
            moveTo(first >= 0 ? first : 0)
        } else if (order.indexOf(currentIndex) >= 0) {
            pos = order.indexOf(currentIndex)
            lastRow = currentIndex
        } else {
            moveTo(Math.min(Math.max(pos, 0), order.length - 1))
        }
    }

    function moveTo(p) {
        const n = order.length
        if (n == 0)
            return
        p = (p + n) % n
        syncing = true
        pos = p
        lastRow = order[p]
        currentIndex = order[p]
        syncing = false
    }

    // Up/Down: the nearest monitor above/below (by centers) that has windows
    function switchOutput(dir) {
        const all = items()
        if (!all || !output)
            return
        const here = output.geometry
        const cy = here.y + here.height / 2, cx = here.x + here.width / 2
        let best = null, bestDist = Infinity
        for (const o of KWin.Workspace.screens) {
            if (o === output || !all.some(i => i.output === o))
                continue
            const g = o.geometry
            const dy = (g.y + g.height / 2 - cy) * dir
            if (dy <= 0)
                continue
            const dist = dy + Math.abs(g.x + g.width / 2 - cx)
            if (dist < bestDist) {
                best = o
                bestDist = dist
            }
        }
        if (!best)
            return
        output = best
        fresh = true
        resort()
    }

    onVisibleChanged: if (visible) {
        output = null
        resort()
    }

    // KWin stepped (Tab / Shift+Tab): take the same step along the shown order.
    // Steps from before the order is known (opening) are adopted as they are.
    onCurrentIndexChanged: {
        if (syncing)
            return
        const n = rows.count
        const d = n > 1 ? (currentIndex - lastRow + n) % n : 0
        const dir = !visible || order.length == 0 ? 0 : d == 1 ? 1 : d == n - 1 ? -1 : 0
        if (dir == 0) {
            pos = order.indexOf(currentIndex)
            lastRow = currentIndex
        } else {
            moveTo(pos + dir)
        }
    }

    Instantiator {
        active: tabBox.visible
        delegate: PlasmaCore.Dialog {
            location: PlasmaCore.Types.Floating
            visible: true
            flags: Qt.Popup | Qt.X11BypassWindowManagerHint
            x: tabBox.area.x + (tabBox.area.width - width) / 2
            y: tabBox.area.y + (tabBox.area.height - height) / 2

            mainItem: FocusScope {
                id: content
                focus: true

                readonly property int fullWidth: tabBox.order.length * tabBox.cellWidth
                width: Math.max(tabBox.cellWidth, Math.min(fullWidth, tabBox.area.width * 0.9)) + 2 * tabBox.pad
                height: tabBox.cellHeight + 2 * tabBox.pad

                Appear { id: appear; targets: [content] }
                Component.onCompleted: appear.open()

                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: tabBox.pad
                    orientation: ListView.Horizontal
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0
                    model: tabBox.order
                    currentIndex: tabBox.pos
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Item {
                        id: cell
                        required property int modelData
                        required property int index
                        readonly property var win: rows.objectAt(modelData)
                        readonly property bool selected: index == tabBox.pos

                        width: tabBox.cellWidth
                        height: tabBox.cellHeight

                        Item {
                            width: tabBox.cellWidth
                            height: tabBox.cellHeight

                            // The keyboard highlight is the one accented thing; hover stays a neutral tint
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                color: cell.selected ? Theme.selectionTint
                                     : mouse.containsMouse ? Theme.hoverTint
                                     : "transparent"
                                Behavior on color {
                                    ColorAnimation { duration: tabBox.hoverDuration; easing.type: tabBox.houseCurve }
                                }
                            }

                            // The window sunk in a well; KWin.WindowThumbnail keeps its aspect ratio
                            Well {
                                x: 7
                                y: 7
                                width: tabBox.thumbWidth + 2
                                height: tabBox.thumbHeight + 2
                                KWin.WindowThumbnail {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    opacity: cell.win && cell.win.minimized ? 0.5 : 1
                                    wId: cell.win ? cell.win.wid : ""
                                }
                            }

                            Row {
                                x: 8
                                y: 8 + tabBox.thumbHeight + 8
                                width: tabBox.thumbWidth
                                height: tabBox.captionHeight
                                spacing: 8

                                Kirigami.Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    height: 16
                                    source: cell.win ? cell.win.icon : ""
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 16 - parent.spacing
                                    text: cell.win ? cell.win.caption : ""
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    font.family: Theme.typeFamilySans
                                    font.pixelSize: Theme.typeSizeBody
                                    color: cell.win && cell.win.minimized ? Theme.textMuted : Theme.text
                                }
                            }

                            MouseArea {
                                id: mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: tabBox.model.activate(cell.modelData)
                            }
                        }
                    }
                }

                Keys.onPressed: event => {
                    if (event.key == Qt.Key_Left)
                        tabBox.moveTo(tabBox.pos - 1)
                    else if (event.key == Qt.Key_Right)
                        tabBox.moveTo(tabBox.pos + 1)
                    else if (event.key == Qt.Key_Up)
                        tabBox.switchOutput(-1)
                    else if (event.key == Qt.Key_Down)
                        tabBox.switchOutput(1)
                    else
                        return
                    event.accepted = true
                }
            }

            onSceneGraphError: () => {
                // Left blank on purpose: otherwise QtQuick may qFatal() on a graphics reset
            }
        }
    }
}
