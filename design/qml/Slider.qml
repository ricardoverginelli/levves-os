// A slider (design/DESIGN.md Pieces): a flat 6px `raised` track, the part up to the value in
// `fill` (fog; fog-deep when it isn't the current one), and a narrow square thumb in `text` that
// turns `glow` while dragged. `mark` puts a tick on the track (e.g. where 100% is on a slider that
// can go past it).
import QtQuick
import QtQuick.Templates as T

T.Slider {
    id: slider
    property color fill: Theme.fog
    property real mark: NaN

    implicitWidth: 160
    implicitHeight: 20
    hoverEnabled: true

    background: Item {
        x: slider.leftPadding
        y: slider.topPadding + (slider.availableHeight - height) / 2
        width: slider.availableWidth
        height: 6

        Rectangle { anchors.fill: parent; color: Theme.raised }
        Rectangle {
            width: slider.visualPosition * parent.width
            height: parent.height
            color: slider.fill
        }
        Rectangle {
            visible: !isNaN(slider.mark)
            x: (slider.mark - slider.from) / (slider.to - slider.from) * parent.width - 1
            y: -3
            width: 2
            height: parent.height + 6
            color: Theme.textFaint
        }
    }

    handle: Rectangle {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + (slider.availableHeight - height) / 2
        width: 6
        height: 16
        color: slider.pressed ? Theme.glow : slider.hovered ? Theme.text : Theme.textSoft
    }
}
