// A window's body (design/DESIGN.md Edges): `surface` inside the black engraved edge, a light
// line top-left and a shade bottom-right. For windows drawn in QML (KWin scripts, apps); Plasma's
// popups get the same frame from the Plasma style. Put a TitleBar and the content inside it.
import QtQuick

Rectangle {
    color: Theme.surface
    radius: Theme.radiusContainer
    border.color: Theme.edge
    border.width: Theme.edgeWidth

    Rectangle {  // the engraved lines, inside the edge
        anchors.fill: parent
        anchors.margins: Theme.edgeWidth
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, Theme.opacityEdgeLight)
    }
    Rectangle {  // the shade over the bottom and right of that line
        x: Theme.edgeWidth; y: parent.height - 2 * Theme.edgeWidth
        width: parent.width - 2 * Theme.edgeWidth; height: 1
        color: Qt.tint(Theme.surface, Qt.rgba(0, 0, 0, Theme.opacityEdgeShade))
    }
    Rectangle {
        x: parent.width - 2 * Theme.edgeWidth; y: Theme.edgeWidth
        width: 1; height: parent.height - 2 * Theme.edgeWidth
        color: Qt.tint(Theme.surface, Qt.rgba(0, 0, 0, Theme.opacityEdgeShade))
    }
}
