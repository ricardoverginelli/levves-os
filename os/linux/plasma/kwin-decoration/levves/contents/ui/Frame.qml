// A Levves window (design/DESIGN.md Pieces, Window): the black engraved edge, D's title bar (the
// light, amber while focused, and the serif title) and small keys for the buttons. Maximized, only
// the title bar is left. Buttons on the left aren't drawn: the light stands where an icon would be.
import QtQuick
import org.kde.kwin.decoration
import Levves

Item {
    id: frame
    required property Item deco  // main.qml's Decoration: its padding holds the shadow

    readonly property var client: decoration.client
    readonly property bool maximized: client.maximized
    readonly property bool active: client.active

    DecorationOptions { id: options; deco: decoration }

    // The shadow, in the padding (KWin turns that part of the decoration into the window's shadow)
    Repeater {
        model: frame.maximized ? 0 : 8
        Rectangle {
            required property int index
            x: win.x - index - 1
            y: win.y - index + 2
            width: win.width + 2 * (index + 1)
            height: win.height + 2 * (index + 1)
            radius: Theme.radiusContainer + index + 1
            color: "black"
            opacity: frame.active ? 0.06 : 0.04
        }
    }

    Item {
        id: win
        x: frame.maximized ? 0 : frame.deco.padding.left
        y: frame.maximized ? 0 : frame.deco.padding.top
        width: frame.width - (frame.maximized ? 0 : frame.deco.padding.left + frame.deco.padding.right)
        height: frame.height - (frame.maximized ? 0 : frame.deco.padding.top + frame.deco.padding.bottom)

        Rectangle {  // the edge
            anchors.fill: parent
            visible: !frame.maximized
            radius: Theme.radiusContainer
            color: Theme.edge
        }

        TitleBar {
            id: bar
            x: frame.maximized ? 0 : 1
            y: x
            width: parent.width - 2 * x
            title: frame.client.caption
            active: frame.active

            Item {
                implicitWidth: buttons.width
                implicitHeight: 20
                ButtonGroup {
                    id: buttons
                    height: 20
                    spacing: 3
                    explicitSpacer: 24
                    buttons: options.titleButtonsRight
                    minimizeButton: minimizeKey
                    maximizeButton: maximizeKey
                    closeButton: closeKey
                    keepAboveButton: keepAboveKey
                }
            }
            Component.onCompleted: decoration.installTitleItem(bar)
        }

        // The engraving: light along the top and left, shade along the right and bottom
        Rectangle { visible: !frame.maximized; x: 1; y: 1; width: parent.width - 2; height: 1; color: frame.light }
        Rectangle { visible: !frame.maximized; x: 1; y: 1; width: 1; height: parent.height - 2; color: frame.light }
        Rectangle { visible: !frame.maximized; x: parent.width - 2; y: 1; width: 1; height: parent.height - 2; color: frame.shade }
        Rectangle { visible: !frame.maximized; x: 1; y: parent.height - 2; width: parent.width - 2; height: 1; color: frame.shade }
    }
    readonly property color light: Qt.rgba(1, 1, 1, Theme.opacityEdgeLight)
    readonly property color shade: Qt.rgba(0, 0, 0, Theme.opacityEdgeShade)

    Component { id: minimizeKey; WindowKey { kind: DecorationOptions.DecorationButtonMinimize } }
    Component { id: maximizeKey; WindowKey { kind: DecorationOptions.DecorationButtonMaximizeRestore } }
    Component { id: closeKey; WindowKey { kind: DecorationOptions.DecorationButtonClose } }
    Component { id: keepAboveKey; WindowKey { kind: DecorationOptions.DecorationButtonKeepAbove } }

    // A small key; close turns critical under the pointer
    component WindowKey: Key {
        id: key
        property int kind
        readonly property bool isClose: kind === DecorationOptions.DecorationButtonClose
        readonly property color ink: !enabled ? Theme.textFaint : frame.active || hovered ? Theme.text : Theme.textMuted

        implicitWidth: 24
        implicitHeight: 20
        leftPadding: 0
        rightPadding: 0
        focusPolicy: Qt.NoFocus
        highlighted: isClose && hovered
        tone: Theme.critical
        current: kind === DecorationOptions.DecorationButtonKeepAbove && frame.client.keepAbove
        enabled: kind === DecorationOptions.DecorationButtonClose ? frame.client.closeable
            : kind === DecorationOptions.DecorationButtonMaximizeRestore ? frame.client.maximizeable
            : kind === DecorationOptions.DecorationButtonMinimize ? frame.client.minimizeable : true

        onClicked: {
            switch (kind) {
            case DecorationOptions.DecorationButtonMinimize: decoration.requestMinimize(); break;
            case DecorationOptions.DecorationButtonMaximizeRestore: decoration.requestToggleMaximization(Qt.LeftButton); break;
            case DecorationOptions.DecorationButtonClose: decoration.requestClose(); break;
            case DecorationOptions.DecorationButtonKeepAbove: decoration.requestToggleKeepAbove(); break;
            }
        }

        // Classic glyphs drawn in whole pixels, so they stay crisp at any size
        contentItem: Item {
            Rectangle {  // minimize: a bar at the bottom
                visible: key.kind === DecorationOptions.DecorationButtonMinimize
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(parent.height / 2) + 2
                width: 8; height: 2
                color: key.ink
            }
            Rectangle {  // maximize: a window with a thick top; restore: two of them
                visible: key.kind === DecorationOptions.DecorationButtonMaximizeRestore
                x: Math.round((parent.width - width) / 2) + (frame.maximized ? 2 : 0)
                y: Math.round((parent.height - height) / 2) - (frame.maximized ? 2 : 0)
                width: frame.maximized ? 7 : 9; height: width
                color: "transparent"
                border.color: key.ink
                Rectangle { width: parent.width; height: 2; color: key.ink }
            }
            Rectangle {
                visible: key.kind === DecorationOptions.DecorationButtonMaximizeRestore && frame.maximized
                x: Math.round((parent.width - width) / 2) - 2
                y: Math.round((parent.height - height) / 2) + 2
                width: 7; height: 7
                color: Theme.raised
                border.color: key.ink
                Rectangle { width: parent.width; height: 2; color: key.ink }
            }
            Repeater {  // close: an X
                model: key.isClose ? [45, -45] : []
                Rectangle {
                    required property int modelData
                    anchors.centerIn: parent
                    width: 11; height: 1.5
                    antialiasing: true
                    rotation: modelData
                    color: key.highlighted ? Theme.critical : key.ink
                }
            }
            Rectangle {  // keep above: a bar over an up arrow's stem
                visible: key.kind === DecorationOptions.DecorationButtonKeepAbove
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(parent.height / 2) - 5
                width: 8; height: 2
                color: key.ink
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 4; width: 2; height: 6; color: key.ink }
            }
        }
    }
}
