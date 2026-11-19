// Copied from design/qml/GroupBox.qml by design/build/build.py. Don't edit here.
// A section (design/DESIGN.md Pieces): a sentence-case label and, optionally, a value on the right,
// over its content, with a hairline under the section that sets it apart from the next (`rule`).
// No frame and no header strip. Children go in the body.
import QtQuick
import QtQuick.Layouts

Item {
    id: box
    property alias title: titleLabel.text
    property alias value: valueLabel.text
    property real padding: Theme.space16
    property bool rule: true
    default property alias content: body.data
    implicitWidth: Math.max(header.implicitWidth, body.implicitWidth) + 2 * padding
    implicitHeight: Theme.sizeGroupHeader + body.implicitHeight + 2 * padding

    RowLayout {
        id: header
        x: box.padding; y: box.padding - 4
        width: box.width - 2 * box.padding
        height: Theme.sizeGroupHeader
        Caps { id: titleLabel; Layout.fillWidth: true; elide: Text.ElideRight }
        Num { id: valueLabel; visible: text !== "" }
    }
    Item {
        id: body
        x: box.padding
        y: header.y + Theme.sizeGroupHeader + 4
        width: box.width - 2 * box.padding
        height: box.height - y - box.padding
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
    Rectangle {
        visible: box.rule
        anchors.bottom: parent.bottom
        width: parent.width; height: Theme.edgeWidth
        color: Theme.border
    }
}
