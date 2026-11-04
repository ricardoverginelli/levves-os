// A status tag: caps text in its tone, a faint fill and outline of the same tone. Status colors
// are for meaning (design/DESIGN.md Color): tone is Theme.warning, success, info, critical or muted.
import QtQuick

Rectangle {
    property alias text: label.text
    property color tone: Theme.textMuted

    implicitWidth: label.implicitWidth + 12
    implicitHeight: label.implicitHeight + 2
    radius: Theme.radiusContainer
    color: Qt.rgba(tone.r, tone.g, tone.b, Theme.opacityTagFill)
    border.color: Qt.rgba(tone.r, tone.g, tone.b, Theme.opacityTagEdge)

    Caps {
        id: label
        anchors.centerIn: parent
        color: parent.tone
        font.pixelSize: 10
        font.letterSpacing: Theme.typeTrackingTag * font.pixelSize
    }
}
