// KWin window switcher (Alt+Tab layout): a row of window thumbnails. Windows on
// the monitor under the mouse come first, then the other monitors', each group
// by last use with minimized windows at its end. A divider splits the groups.
//
//   ┌─────────────────────────────────────────────┐
//   │ ┌────┐ ┌────┐ ┌────┐  │  ┌────┐ ┌────┐      │
//   │ │ ▢  │ │ ▢  │ │ ▢  │  │  │ ▢  │ │ ▢  │      │
//   │ └────┘ └────┘ └────┘  │  └────┘ └────┘      │
//   │  this monitor            other monitors      │
//   └─────────────────────────────────────────────┘
//
// KWin keeps its own order (last use) and steps through it on Tab; releasing
// Alt activates its current row. So the layout keeps `order` (shown position →
// KWin row) and turns each step KWin takes into a step along the shown order,
// writing the row there back to KWin. Arrows are handled here directly.
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin

KWin.TabBoxSwitcher {
    id: tabBox

    // DESIGN.md motion and spacing
    readonly property int houseCurve: Easing.OutQuint
    readonly property int openDuration: 240
    readonly property int hoverDuration: 150
    readonly property int pad: 12
    readonly property int thumbWidth: 240
    readonly property int thumbHeight: 150
    readonly property int captionHeight: 20
    readonly property int cellWidth: thumbWidth + 2 * 8
    readonly property int cellHeight: 8 + thumbHeight + 8 + captionHeight + 8
    readonly property int dividerGap: 24  // DESIGN.md: between sections, a 1px line in the middle

    property var order: []    // shown position → KWin row
    property int splitAt: -1  // first shown position of the other monitors' windows; -1 when there's one group
    property int pos: -1      // shown position of KWin's current row
    property int lastRow: -1  // KWin's current row as last seen, to tell which way it stepped
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

    function resort() {
        const byId = {}
        for (const w of KWin.Workspace.windows)
            byId[w.internalId.toString()] = w
        const screen = KWin.Workspace.activeScreen
        const items = []
        for (let row = 0; row < rows.count; row++) {
            const o = rows.objectAt(row)
            if (!o)
                return
            const w = byId[o.wid ? o.wid.toString() : ""]
            items.push({ row: row, group: w && w.output === screen ? 0 : 1, minimized: o.minimized })
        }
        items.sort((a, b) => a.group - b.group || a.minimized - b.minimized || a.row - b.row)
        const split = items.findIndex(i => i.group == 1)
        order = items.map(i => i.row)
        splitAt = split > 0 ? split : -1
        pos = order.indexOf(currentIndex)
        lastRow = currentIndex
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

    onVisibleChanged: if (visible) resort()

    // KWin stepped (Tab / Shift+Tab): take the same step along the shown order.
    // Steps from before the order is known (opening) are adopted as they are.
    onCurrentIndexChanged: {
        if (syncing)
            return
        const n = order.length
        const d = n > 1 ? (currentIndex - lastRow + n) % n : 0
        const dir = !visible || n != rows.count ? 0 : d == 1 ? 1 : d == n - 1 ? -1 : 0
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
            x: tabBox.screenGeometry.x + (tabBox.screenGeometry.width - width) / 2
            y: tabBox.screenGeometry.y + (tabBox.screenGeometry.height - height) / 2

            mainItem: FocusScope {
                id: content
                focus: true

                readonly property int dividers: tabBox.splitAt > 0 ? 1 : 0
                readonly property int fullWidth: tabBox.order.length * tabBox.cellWidth + dividers * tabBox.dividerGap
                width: Math.max(tabBox.cellWidth, Math.min(fullWidth, tabBox.screenGeometry.width * 0.9)) + 2 * tabBox.pad
                height: tabBox.cellHeight + 2 * tabBox.pad

                NumberAnimation on opacity { from: 0; to: 1; duration: tabBox.openDuration; easing.type: tabBox.houseCurve }
                NumberAnimation on scale { from: 0.96; to: 1; duration: tabBox.openDuration; easing.type: tabBox.houseCurve }

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
                        readonly property bool leadsGroup: index == tabBox.splitAt
                        readonly property int lead: leadsGroup ? tabBox.dividerGap : 0

                        width: lead + tabBox.cellWidth
                        height: tabBox.cellHeight

                        Rectangle {
                            visible: cell.leadsGroup
                            x: Math.round(cell.lead / 2)
                            y: 8
                            width: 1
                            height: parent.height - 16
                            color: "#2e383d"  // DESIGN.md border
                        }

                        Item {
                            x: cell.lead
                            width: tabBox.cellWidth
                            height: tabBox.cellHeight

                            // The keyboard highlight is the one accented thing; hover stays a neutral tint
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: 6  // DESIGN.md: cards inside a popup
                                color: cell.selected ? Qt.alpha(Kirigami.Theme.highlightColor, 0.18)
                                     : mouse.containsMouse ? Qt.alpha(Kirigami.Theme.textColor, 0.06)
                                     : "transparent"
                                Behavior on color {
                                    ColorAnimation { duration: tabBox.hoverDuration; easing.type: tabBox.houseCurve }
                                }
                            }

                            // KWin.WindowThumbnail needs a container; it keeps the window's aspect ratio
                            Item {
                                x: 8
                                y: 8
                                width: tabBox.thumbWidth
                                height: tabBox.thumbHeight
                                opacity: cell.win && cell.win.minimized ? 0.5 : 1
                                KWin.WindowThumbnail {
                                    anchors.fill: parent
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
                                    font.family: "Noto Sans"
                                    font.pointSize: 10
                                    color: Kirigami.Theme.textColor
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
