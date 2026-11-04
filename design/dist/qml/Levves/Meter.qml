// Copied from design/qml/Meter.qml by design/build/build.py. Don't edit here.
// A meter (design/DESIGN.md Pieces): a sunken, dithered track with a fill of 10px segments.
import QtQuick

Rectangle {
    id: meter
    property real value: 0              // 0 to 1
    property color fill: Theme.textMuted

    implicitHeight: 14
    color: Theme.well
    border.color: Theme.edge

    Dither { anchors.fill: parent; anchors.margins: 1; tone: "well" }
    Item {
        x: 2; y: 2
        width: (meter.width - 4) * Math.max(0, Math.min(1, meter.value))
        height: meter.height - 4
        clip: true
        Row {
            spacing: 2
            Repeater {
                model: Math.ceil((meter.width - 4) / 12)
                Rectangle { width: 10; height: meter.height - 4; color: meter.fill }
            }
        }
    }
}
