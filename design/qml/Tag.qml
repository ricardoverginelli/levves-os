// A status tag: semibold text in its tone on a plane of the same tone, no outline. Status colors
// are for meaning (design/DESIGN.md Color): tone is Theme.warning, success, info, critical or muted.
import QtQuick

Rectangle {
    property alias text: label.text
    property color tone: Theme.textMuted
    implicitWidth: label.implicitWidth + 2 * Theme.space8
    implicitHeight: label.implicitHeight + 4
    color: Qt.rgba(tone.r, tone.g, tone.b, Theme.opacityTagFill)
    Caps {
        id: label
        anchors.centerIn: parent
        color: parent.tone
        size: Theme.typeSizeSmall
        tracking: Theme.typeTrackingTag
    }
}
