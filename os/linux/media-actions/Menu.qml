// The middle-click menu: Cut / Convert ▸ formats, opened at the pointer.
// A transparent layer-shell overlay over the whole monitor learns where the
// pointer is when it appears and puts the menu there; a click outside or Esc
// closes it. Convert cascades into a submenu on hover. Image-only selections
// have nothing but Convert, so they get the formats as the menu itself.
// Leaves look (~/repos/levves/os/linux/plasma/DESIGN.md).
import QtQuick
import Levves
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell

Window {
    id: win
    width: 800
    height: 600
    color: "transparent"
    flags: Qt.FramelessWindowHint
    visible: true

    LayerShell.Window.scope: "media-actions"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                               | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityExclusive
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.screenConfiguration: LayerShell.Window.ScreenFromCompositor

    readonly property var mainRows: menu.canCut
        ? [{ id: "cut", label: "Cut", hint: "LosslessCut", icon: "mingcute-scissors-fill" },
           { id: "convert", label: "Convert", hint: "", icon: "mingcute-transfer-horizontal-fill", more: true }]
        : menu.formats
    property bool subOpen: false
    property int level: 0  // which card the keyboard is in: 0 main, 1 submenu
    property real px: -1
    property real py: -1
    property bool closing: false

    function place(x, y) {
        if (px >= 0)
            return
        px = x
        py = y
    }

    function close(choice) {
        if (closing)
            return
        closing = true
        closeAnim.choice = choice
        closeAnim.close()
    }

    function openSub(withKeyboard) {
        hoverTimer.stop()
        subOpen = true
        if (withKeyboard) {
            level = 1
            sub.current = 0
        }
    }

    function closeSub() {
        hoverTimer.stop()
        subOpen = false
        level = 0
        sub.current = -1
    }

    // Hovering Convert opens the submenu after a short rest; hovering away closes it
    // after a grace, so a diagonal trip toward the submenu doesn't (DESIGN.md hover-open)
    Timer {
        id: hoverTimer
        property bool opening
        interval: opening ? 150 : 400
        onTriggered: opening ? win.openSub(false) : win.closeSub()
    }

    // Where the pointer is when the overlay maps; the middle of the screen if it never says
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onEntered: win.place(mouseX, mouseY)
        onPositionChanged: mouse => win.place(mouse.x, mouse.y)
        onPressed: win.close("")
    }
    Timer {
        interval: 200
        running: true
        onTriggered: win.place(win.width / 2 - main.width / 2, win.height / 2 - main.height / 2)
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const card = win.level === 1 ? sub : main
            const n = card.rows.length
            if (event.key === Qt.Key_Escape)
                win.close("")
            else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)
                card.current = (card.current + 1) % n
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)
                card.current = (card.current - 1 + n) % n
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                     || event.key === Qt.Key_Right || event.key === Qt.Key_Space)
                card.activate(Math.max(0, card.current), true)
            else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Backspace) && win.level === 1)
                win.closeSub()
            else
                return
            event.accepted = true
        }
    }

    // Cards close together; the choice runs once they're gone
    Appear {
        id: closeAnim
        property string choice
        targets: [main, sub]
        onClosed: menu.choose(choice)
    }

    MenuCard {
        id: main
        shown: win.px >= 0
        rows: win.mainRows
        // Below-right of the pointer, flipped to stay on screen
        x: win.px + width + 8 > win.width ? Math.max(8, win.px - width) : win.px
        y: win.py + height + 8 > win.height ? Math.max(8, win.py - height) : win.py
        onRowHovered: i => {
            if (i < 0 || !menu.canCut)
                return
            current = -1
            const convert = rows[i].id === "convert"
            if (convert === win.subOpen) {
                hoverTimer.stop()
            } else {
                hoverTimer.opening = convert
                hoverTimer.restart()
            }
        }
        onActivated: (id, withKeyboard) => id === "convert" ? win.openSub(withKeyboard) : win.close(id)
    }

    MenuCard {
        id: sub
        readonly property bool flip: main.x + main.width + 4 + width + 8 > win.width
        shown: menu.canCut && win.subOpen && main.shown
        rows: menu.formats
        // Beside the Convert row, its first row level with it (minus the card's padding)
        x: flip ? main.x - width - 4 : main.x + main.width + 4
        y: Math.max(8, Math.min(main.y + 32, win.height - height - 8))
        transformOrigin: flip ? Item.TopRight : Item.TopLeft
        onRowHovered: i => {
            if (i < 0)
                return
            current = -1
            win.level = 1
            hoverTimer.stop()  // made it into the submenu: keep it open
        }
        onActivated: id => win.close(id)
    }

    component MenuCard: WindowFrame {
        id: card
        property var rows: []
        property int current: -1  // keyboard highlight, -1 until an arrow key is used
        property bool shown: false
        signal rowHovered(int index)
        signal activated(string id, bool withKeyboard)

        function activate(i, withKeyboard) {
            if (rows[i])
                activated(rows[i].id, withKeyboard)
        }

        visible: opacity > 0
        width: 220
        height: column.implicitHeight + 8
        transformOrigin: Item.TopLeft

        // Not a Plasma window, so it opens itself (Appear)
        opacity: 0
        scale: Theme.scaleAppear
        onShownChanged: {
            if (!win.closing)
                shown ? cardAppear.open() : cardAppear.close()
        }
        Appear { id: cardAppear; targets: [card] }

        MouseArea { anchors.fill: parent; enabled: card.shown }  // clicks between rows don't close it

        Column {
            id: column
            x: 4
            y: 4
            width: parent.width - 8

            Repeater {
                model: card.rows
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool open: !!modelData.more && win.subOpen
                    width: column.width
                    height: Theme.sizeRow

                    Rectangle {  // square rows, as in a Levves list
                        anchors.fill: parent
                        color: card.current === row.index ? Theme.selectionTint
                             : area.containsMouse || row.open ? Theme.hoverTint : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.durationHover } }
                    }
                    Kirigami.Icon {
                        id: icon
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        source: row.modelData.icon
                        isMask: true
                        color: Theme.textMuted
                    }
                    Text {
                        anchors.left: icon.right
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.label
                        font.family: Theme.typeFamilySans
                        font.pixelSize: Theme.typeSizeBody
                        color: Theme.text
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !row.modelData.more
                        text: row.modelData.hint
                        font.family: Theme.typeFamilySans
                        font.pixelSize: Theme.typeSizeSmall
                        color: Theme.textMuted
                    }
                    Kirigami.Icon {
                        visible: !!row.modelData.more
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        source: sub.flip ? "mingcute-left-fill" : "mingcute-right-fill"
                        isMask: true
                        color: Theme.textMuted
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        enabled: card.shown
                        hoverEnabled: true
                        onContainsMouseChanged: if (containsMouse) card.rowHovered(row.index)
                        onClicked: card.activate(row.index, false)
                    }
                }
            }
        }
    }
}
