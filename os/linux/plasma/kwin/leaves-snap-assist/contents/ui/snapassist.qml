// KWin script: snap assist. Meta+Shift+Left/Right tiles the active window to
// that half of its monitor, then shows the monitor's other windows in the empty
// half; the one picked is tiled there. With a single other window it's tiled
// right away, with none nothing is shown.
//
//   ┌──────────────┬──────────────┐
//   │              │ ┌────┐┌────┐ │
//   │   window     │ │ ▢  ││ ▢  │ │   picker: thumbnails of the monitor's
//   │   (tiled)    │ └────┘└────┘ │   other windows, centered in the empty half
//   │              │              │
//   └──────────────┴──────────────┘
//
// Keys: arrows move the highlight, Enter/Space picks, Esc or a click outside
// cancels (the first window stays tiled).
//
// The shortcuts have no keys of their own: kwin/leaves-windows owns
// Meta+Shift+Left/Right (spanning columns on a monitor with a layout) and
// invokes these on a monitor without one. Plain Meta+Left/Right tile halves
// there (no picker), also through leaves-windows.
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin
import Levves

Item {
    id: root

    // Levves motion and spacing (design/DESIGN.md)
    readonly property int houseCurve: Easing.OutQuint
    readonly property int openDuration: Theme.durationPopupOpen
    readonly property int closeDuration: Theme.durationPopupClose
    readonly property int hoverDuration: Theme.durationHover
    readonly property int pad: Theme.space12
    readonly property int thumbWidth: 240
    readonly property int thumbHeight: 150
    readonly property int captionHeight: 20
    readonly property int maxColumns: 3
    readonly property int cellWidth: thumbWidth + 2 * 8
    readonly property int cellHeight: 8 + thumbHeight + 8 + captionHeight + 8

    // Picker state: the side still empty, its area and the windows offered
    property string emptySide: ""
    property rect emptyArea
    property var candidates: []
    property bool closing: false

    KWin.ShortcutHandler {
        name: "Leaves Snap Assist Left"
        text: "Leaves: tile window left and pick one for the right"
        sequence: "Meta+Shift+Left"
        onActivated: root.assist("left")
    }

    KWin.ShortcutHandler {
        name: "Leaves Snap Assist Right"
        text: "Leaves: tile window right and pick one for the left"
        sequence: "Meta+Shift+Right"
        onActivated: root.assist("right")
    }

    // ── Logic ─────────────────────────────────────────────────────────────

    function isOnCurrentDesktop(w) {
        return w.onAllDesktops || w.desktops.indexOf(KWin.Workspace.currentDesktop) != -1
    }

    function workArea(output) {
        return KWin.Workspace.clientArea(KWin.Workspace.MaximizeArea, output, KWin.Workspace.currentDesktop)
    }

    // Quick tiles leave a little padding, so compare loosely
    function isTiledTo(w, side) {
        if (!w.tile)
            return false
        const g = w.tile.absoluteGeometry, area = workArea(w.output), slack = 16
        const halfWidth = Math.abs(g.width - area.width / 2) < slack
        const atEdge = side == "left" ? Math.abs(g.x - area.x) < slack
                                      : Math.abs(g.x + g.width - (area.x + area.width)) < slack
        return halfWidth && atEdge && Math.abs(g.height - area.height) < slack
    }

    // KWin's quick tile acts on the active window, and tiling an already tiled
    // window to the same side would move or untile it, so skip that case
    function tile(w, side) {
        w.minimized = false
        KWin.Workspace.activeWindow = w
        if (isTiledTo(w, side))
            return
        if (side == "left")
            KWin.Workspace.slotWindowQuickTileLeft()
        else
            KWin.Workspace.slotWindowQuickTileRight()
    }

    // The monitor's other windows, most recently used first
    function otherWindows(w) {
        const order = KWin.Workspace.stackingOrder.slice().reverse()
        return order.filter(x => x != w && x.normalWindow && !x.skipSwitcher
                            && x.output == w.output && isOnCurrentDesktop(x))
    }

    function assist(side) {
        const w = KWin.Workspace.activeWindow
        if (!w || !w.normalWindow || picker.visible)
            return
        tile(w, side)

        const others = otherWindows(w)
        const other = side == "left" ? "right" : "left"
        if (others.length == 0)
            return
        if (others.length == 1) {
            tile(others[0], other)
            return
        }

        const area = workArea(w.output)
        const halfWidth = Math.floor(area.width / 2)
        emptySide = other
        emptyArea = Qt.rect(other == "left" ? area.x : area.x + area.width - halfWidth, area.y, halfWidth, area.height)
        candidates = others
        open()
    }

    function pick(w) {
        const side = emptySide
        close()
        if (w)
            tile(w, side)
    }

    function open() {
        closing = false
        grid.currentIndex = 0
        const columns = Math.min(candidates.length, maxColumns,
                                 Math.max(1, Math.floor((emptyArea.width * 0.9 - 2 * pad) / cellWidth)))
        const rows = Math.ceil(candidates.length / columns)
        const contentWidth = columns * cellWidth + 2 * pad
        const contentHeight = Math.min(rows * cellHeight, emptyArea.height * 0.8) + 2 * pad
        picker.width = contentWidth + picker.leftPadding + picker.rightPadding
        picker.height = contentHeight + picker.topPadding + picker.bottomPadding
        picker.x = emptyArea.x + Math.round((emptyArea.width - picker.width) / 2)
        picker.y = emptyArea.y + Math.round((emptyArea.height - picker.height) / 2)
        closeAnim.stop()
        picker.visible = true
        openAnim.restart()
    }

    function close() {
        if (!picker.visible || closing)
            return
        closing = true
        openAnim.stop()
        closeAnim.restart()
    }

    // Clicking another window counts as a cancel
    Connections {
        target: KWin.Workspace
        function onWindowActivated(w) {
            if (picker.visible && w && root.candidates.indexOf(w) == -1)
                root.close()
        }
    }

    // ── Keys ──────────────────────────────────────────────────────────────

    // KWin keeps keyboard focus on the app window and never sends keys to a
    // script's window, so the picker's keys are global shortcuts that only
    // exist while it's open (destroying a ShortcutHandler releases its key)
    component PickerKey: KWin.ShortcutHandler {
        required property string key
        name: "Leaves Snap Assist Picker " + key
        text: "Leaves: snap assist picker, " + key + " (only while it's open)"
        sequence: key
    }

    Loader {
        active: picker.visible && !root.closing
        sourceComponent: Item {
            PickerKey { key: "Left"; onActivated: grid.moveCurrentIndexLeft() }
            PickerKey { key: "Right"; onActivated: grid.moveCurrentIndexRight() }
            PickerKey { key: "Up"; onActivated: grid.moveCurrentIndexUp() }
            PickerKey { key: "Down"; onActivated: grid.moveCurrentIndexDown() }
            PickerKey { key: "Return"; onActivated: root.pick(root.candidates[grid.currentIndex]) }
            PickerKey { key: "Enter"; onActivated: root.pick(root.candidates[grid.currentIndex]) }
            PickerKey { key: "Space"; onActivated: root.pick(root.candidates[grid.currentIndex]) }
            PickerKey { key: "Esc"; onActivated: root.close() }
        }
    }

    // ── Window ────────────────────────────────────────────────────────────

    PlasmaCore.Window {
        id: picker
        visible: false
        flags: Qt.X11BypassWindowManagerHint | Qt.FramelessWindowHint

        mainItem: Item {
            id: content
            width: picker.width - picker.leftPadding - picker.rightPadding
            height: picker.height - picker.topPadding - picker.bottomPadding

            ParallelAnimation {
                id: openAnim
                NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: root.openDuration; easing.type: root.houseCurve }
                NumberAnimation { target: content; property: "scale"; from: 0.96; to: 1; duration: root.openDuration; easing.type: root.houseCurve }
            }
            SequentialAnimation {
                id: closeAnim
                ParallelAnimation {
                    NumberAnimation { target: content; property: "opacity"; to: 0; duration: root.closeDuration; easing.type: root.houseCurve }
                    NumberAnimation { target: content; property: "scale"; to: 0.96; duration: root.closeDuration; easing.type: root.houseCurve }
                }
                ScriptAction { script: { picker.visible = false; root.candidates = []; root.closing = false } }
            }

            GridView {
                id: grid
                anchors.fill: parent
                anchors.margins: root.pad
                cellWidth: root.cellWidth
                cellHeight: root.cellHeight
                clip: true
                highlightMoveDuration: 0
                boundsBehavior: Flickable.StopAtBounds
                model: root.candidates

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool selected: GridView.isCurrentItem

                    width: root.cellWidth
                    height: root.cellHeight

                    // The keyboard highlight is the one accented thing; hover stays a neutral tint
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        color: cell.selected ? Theme.selectionTint
                             : mouse.containsMouse ? Theme.hoverTint
                             : "transparent"
                        Behavior on color {
                            ColorAnimation { duration: root.hoverDuration; easing.type: root.houseCurve }
                        }
                    }

                    // The window sunk in a well; KWin.WindowThumbnail keeps its aspect ratio
                    Well {
                        x: 7
                        y: 7
                        width: root.thumbWidth + 2
                        height: root.thumbHeight + 2
                        KWin.WindowThumbnail {
                            anchors.fill: parent
                            anchors.margins: 1
                            wId: cell.modelData.internalId
                        }
                    }

                    Row {
                        x: 8
                        y: 8 + root.thumbHeight + 8
                        width: root.thumbWidth
                        height: root.captionHeight
                        spacing: 8

                        Kirigami.Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            source: cell.modelData.icon
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 16 - parent.spacing
                            text: cell.modelData.caption
                            elide: Text.ElideRight
                            font.family: Theme.typeFamilySans
                            font.pixelSize: Theme.typeSizeBody
                            color: Theme.text
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.pick(cell.modelData)
                    }
                }
            }
        }
    }
}
