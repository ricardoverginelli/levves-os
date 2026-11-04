// A slider (design/DESIGN.md Pieces): a sunk 4px groove, the part up to the value filled, and a
// thumb shaped like a small key. The thumb turns amber while dragged, the one accent then.
// `mark` puts a tick on the groove (e.g. where 100% is on a slider that can go past it).
import QtQuick
import QtQuick.Templates as T

T.Slider {
    id: slider
    property color fill: Theme.textMuted
    property real mark: NaN

    implicitWidth: 160
    implicitHeight: 24
    hoverEnabled: true

    background: Item {
        x: slider.leftPadding
        y: slider.topPadding + (slider.availableHeight - height) / 2
        width: slider.availableWidth
        height: 6

        Rectangle {  // the groove: a dark line with an edge above and a lighter one below
            anchors.fill: parent
            color: Theme.edge
            Rectangle { width: parent.width; height: 1; color: "black" }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.keyEdge }
        }
        Rectangle {
            x: 1; y: 1
            width: Math.max(0, slider.visualPosition * (parent.width - 2))
            height: parent.height - 2
            color: slider.fill
        }
        Rectangle {
            visible: !isNaN(slider.mark)
            x: (slider.mark - slider.from) / (slider.to - slider.from) * parent.width - 1
            y: -3
            width: 2
            height: parent.height + 6
            color: Theme.border
        }
    }

    handle: Item {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + (slider.availableHeight - height) / 2
        width: 14
        height: 22

        Rectangle {  // the bottom edge
            anchors.fill: parent
            radius: Theme.radiusKey
            color: slider.pressed ? Theme.accentEdge : Theme.keyDepth
        }
        Rectangle {
            anchors.fill: parent
            anchors.bottomMargin: Theme.edgeKeyDepth
            radius: Theme.radiusKey
            color: slider.pressed ? Theme.accentHover : Theme.keyEdge
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.edgeWidth
            anchors.bottomMargin: Theme.edgeKeyDepth
            radius: Theme.radiusKey - 1
            color: slider.pressed ? Theme.accent : Theme.raised

            Rectangle {  // hover tint
                anchors.fill: parent
                visible: slider.hovered && !slider.pressed
                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, Theme.opacityHover)
            }
            Rectangle {  // the grip
                anchors.centerIn: parent
                width: parent.width - 4
                height: 2
                color: slider.pressed ? Theme.accentEdge : Theme.keyEdge
            }
        }
    }
}
