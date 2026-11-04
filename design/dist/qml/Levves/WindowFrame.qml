// Copied from design/qml/WindowFrame.qml by design/build/build.py. Don't edit here.
// A window's body (design/DESIGN.md Edges): `surface` inside the black engraved edge, a light
// line top-left and a shade bottom-right. For windows drawn in QML (KWin scripts, apps, the window
// decoration); Plasma's popups get the same frame from the Plasma style. Put a TitleBar and the
// content inside it: the edge and its lines stay drawn over them.
//
// `docked` is for a window flush against a monitor edge (a side panel, a dock): the one side that
// faces the screen ("left" for a window docked on the right) gets the edge and the light, square.
// `bare` draws no edge at all (a maximized window), only the fill.
import QtQuick

Rectangle {
    id: frame
    property string docked: ""
    property bool bare: false
    readonly property bool free: docked === "" && !bare

    color: Theme.surface
    radius: free ? Theme.radiusContainer : 0
    border.color: Theme.edge
    border.width: free ? Theme.edgeWidth : 0

    // A free window: the light along the top and left inside the edge, the shade along the
    // bottom and right
    Rectangle {
        z: 1
        visible: frame.free
        anchors.fill: parent
        anchors.margins: Theme.edgeWidth
        color: "transparent"
        border.width: 1
        border.color: Theme.edgeLight
    }
    Rectangle {
        z: 1
        visible: frame.free
        x: Theme.edgeWidth; y: parent.height - 2 * Theme.edgeWidth
        width: parent.width - 2 * Theme.edgeWidth; height: 1
        color: Theme.edgeShade
    }
    Rectangle {
        z: 1
        visible: frame.free
        x: parent.width - 2 * Theme.edgeWidth; y: Theme.edgeWidth
        width: 1; height: parent.height - 3 * Theme.edgeWidth
        color: Theme.edgeShade
    }

    // A docked window: the edge, then the light, on the side that faces the screen
    Repeater {
        model: frame.docked === "" || frame.bare ? [] : [Theme.edge, Theme.edgeLight]
        Rectangle {
            required property color modelData
            required property int index
            readonly property bool across: frame.docked === "top" || frame.docked === "bottom"
            z: 1
            color: modelData
            width: across ? frame.width : 1
            height: across ? 1 : frame.height
            x: frame.docked === "left" ? index : frame.docked === "right" ? frame.width - 1 - index : 0
            y: frame.docked === "top" ? index : frame.docked === "bottom" ? frame.height - 1 - index : 0
        }
    }
}
