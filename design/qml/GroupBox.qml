// A framed section (design/DESIGN.md Pieces): an etched box with a dithered header strip holding a
// caps label and, optionally, a value on the right. Children go in the body, 12px from the edge.
import QtQuick
import QtQuick.Layouts

Item {
    id: box
    property alias title: titleLabel.text
    property alias value: valueLabel.text
    property real padding: Theme.space12
    default property alias content: body.data

    implicitWidth: Math.max(header.implicitWidth, body.implicitWidth + 2 * padding) + 2
    implicitHeight: Theme.sizeGroupHeader + body.implicitHeight + 2 * padding + 2

    Rectangle {  // the etch: a light line just outside the edge, bottom-right
        x: 1; y: 1; width: parent.width; height: parent.height
        radius: Theme.radiusContainer
        color: "transparent"
        border.color: Theme.etchLight
    }
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusContainer
        color: "transparent"
        border.color: Theme.edge
    }

    Item {
        id: header
        x: 1; y: 1
        width: parent.width - 2
        height: Theme.sizeGroupHeader - 1
        implicitWidth: headerRow.implicitWidth + 2 * Theme.space12
        clip: true

        Dither { anchors.fill: parent }
        RowLayout {
            id: headerRow
            anchors.fill: parent
            anchors.leftMargin: Theme.space12 - 2
            anchors.rightMargin: Theme.space12 - 2
            Caps { id: titleLabel; Layout.fillWidth: true; elide: Text.ElideRight }
            Num { id: valueLabel; visible: text !== ""; color: Theme.textMuted }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.edge }
    }

    Item {
        id: body
        x: box.padding + 1
        y: Theme.sizeGroupHeader + box.padding
        width: box.width - 2 * box.padding - 2
        height: box.height - y - box.padding - 1
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
