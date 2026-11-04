// Copied from design/qml/Led.qml by design/build/build.py. Don't edit here.
// The light in a title bar: amber while its window has focus, `border` otherwise.
import QtQuick

Item {
    property bool lit: true

    implicitWidth: Theme.sizeLed
    implicitHeight: Theme.sizeLed

    Rectangle {  // the glow
        anchors.centerIn: parent
        width: parent.width * 2.5; height: width; radius: width / 2
        color: Theme.accent
        opacity: parent.lit ? 0.18 : 0
    }
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: parent.lit ? Theme.accent : Theme.border
    }
}
