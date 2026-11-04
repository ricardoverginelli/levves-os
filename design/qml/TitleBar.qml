// A window's title bar: the light, the serif title, then whatever goes on the right (keys).
import QtQuick
import QtQuick.Layouts

Rectangle {
    property alias title: label.text
    property bool active: true
    default property alias trailing: trailingRow.data

    implicitHeight: Theme.sizeTitleBar
    color: active ? Theme.titleBar : Theme.titleBarInactive

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space12
        anchors.rightMargin: 5
        spacing: Theme.space8

        Led { lit: active }
        Title {
            id: label
            Layout.fillWidth: true
            color: active ? Theme.text : Theme.textMuted
        }
        RowLayout { id: trailingRow; spacing: 3 }
    }
    Rectangle {  // the edge under it
        anchors.bottom: parent.bottom
        width: parent.width; height: Theme.edgeWidth
        color: Theme.edge
    }
}
