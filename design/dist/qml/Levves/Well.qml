// Copied from design/qml/Well.qml by design/build/build.py. Don't edit here.
// A sunken container: readouts, lists, slots. The black edge with an inner shadow top-left.
import QtQuick

Rectangle {
    color: Theme.well
    border.color: Theme.edge
    border.width: Theme.edgeWidth

    Rectangle {  // inner shadow along the top
        x: Theme.edgeWidth; y: Theme.edgeWidth
        width: parent.width - 2 * Theme.edgeWidth; height: 1
        color: Qt.rgba(0, 0, 0, 0.6)
    }
    Rectangle {  // and the left
        x: Theme.edgeWidth; y: Theme.edgeWidth
        width: 1; height: parent.height - 2 * Theme.edgeWidth
        color: Qt.rgba(0, 0, 0, 0.6)
    }
}
