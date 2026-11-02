// A monitor split into columns: an outlined rectangle with a line between
// each column (1 = no layout, the plain rectangle).
import QtQuick

Item {
    id: glyph

    property int columns: 1
    property color color
    property int lineWidth: 1

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: 2
        border.width: glyph.lineWidth
        border.color: glyph.color
    }

    Repeater {
        model: glyph.columns - 1
        Rectangle {
            required property int index
            x: Math.round(glyph.width * (index + 1) / glyph.columns - glyph.lineWidth / 2)
            width: glyph.lineWidth
            height: glyph.height
            color: glyph.color
        }
    }
}
