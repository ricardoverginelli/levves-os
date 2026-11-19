// A meter (design/DESIGN.md Pieces): a row of lit cells, like the towers' windows. Lit cells in
// `fill` (fog by default), unlit ones `raised`. `cell` is a cell's width; 3 makes the bar's small meters.
import QtQuick

Item {
    id: meter
    property real value: 0              // 0 to 1
    property color fill: Theme.fog
    property real cell: 10
    property real gap: 2
    implicitHeight: 10
    readonly property int count: Math.max(1, Math.floor((width + gap) / (cell + gap)))
    readonly property int lit: Math.round(count * Math.max(0, Math.min(1, value)))
    Row {
        spacing: meter.gap
        Repeater {
            model: meter.count
            Rectangle {
                required property int index
                width: meter.cell; height: meter.height
                color: index < meter.lit ? meter.fill : Theme.raised
            }
        }
    }
}
