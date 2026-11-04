// A field's frame (design/DESIGN.md Pieces): a `well` with the lighter `field-edge` and an inner
// shadow. Use it as a TextField's background, or behind a toggle or a slot.
import QtQuick

Rectangle {
    color: Theme.well
    radius: Theme.radiusContainer
    border.color: Theme.fieldEdge
    border.width: Theme.edgeWidth
    implicitHeight: Theme.sizeKey

    Rectangle {
        x: Theme.edgeWidth; y: Theme.edgeWidth
        width: parent.width - 2 * Theme.edgeWidth; height: 3
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.5) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
