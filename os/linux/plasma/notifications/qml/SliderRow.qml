// One row of the Leaves panel: icon, name, slider, value, and an optional mute button.
// Used for app streams, audio devices and monitors (Controls.qml).
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

import Levves

RowLayout {
    id: row

    property alias text: label.text
    property string iconSource
    // MingCute icons are masks in text-muted; app icons keep their own colors (DESIGN.md Icons)
    property bool iconIsMask: iconSource.startsWith("mingcute-")
    property real from: 0
    property real to: 100
    property real value: 0
    property bool muted: false
    property bool mutable: false
    // Shown while the value can go over 100% (audio boost)
    property real normal: to
    // Click on the name (e.g. make a device the default); the dot shows the state
    property bool selectable: false
    property bool selected: false

    signal moved(real value)
    signal muteToggled()
    signal selectRequested()

    spacing: 12
    implicitHeight: 40

    Kirigami.Icon {
        Layout.preferredWidth: row.iconIsMask ? 16 : 24
        Layout.preferredHeight: Layout.preferredWidth
        Layout.leftMargin: row.iconIsMask ? 4 : 0
        Layout.rightMargin: row.iconIsMask ? 4 : 0
        source: row.iconSource
        isMask: row.iconIsMask
        color: Theme.textMuted
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4  // DESIGN.md: a label and its control

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Default-device marker: a slot, its square knob lit when selected
            Field {
                visible: row.selectable
                implicitWidth: 12
                implicitHeight: 12
                Rectangle {
                    anchors.centerIn: parent
                    width: 6
                    height: 6
                    radius: 1
                    color: row.selected ? Theme.text : "transparent"
                }
            }

            Text {
                id: label
                Layout.fillWidth: true
                elide: Text.ElideRight
                textFormat: Text.PlainText
                font.family: Theme.typeFamilySans
                font.pixelSize: Theme.typeSizeBody
                color: row.muted ? Theme.textMuted : Theme.text

                TapHandler {
                    enabled: row.selectable && !row.selected
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onTapped: row.selectRequested()
                }
            }

            Num {
                Layout.minimumWidth: 32
                horizontalAlignment: Text.AlignRight
                text: Math.round(100 * (slider.pressed ? slider.value : row.value) / row.normal)
                color: Theme.textMuted
                font.pixelSize: Theme.typeSizeBar
            }
        }

        Slider {
            id: slider
            Layout.fillWidth: true
            from: row.from
            to: row.to
            stepSize: (row.normal - row.from) / 100
            enabled: !row.muted || row.mutable
            onMoved: row.moved(value)
            fill: row.muted ? Theme.textFaint : Theme.textMuted
            mark: row.normal < row.to ? row.normal : NaN

            Binding on value {
                when: !slider.pressed
                value: row.value
            }
        }
    }

    PlasmaComponents3.ToolButton {
        visible: row.mutable
        Layout.alignment: Qt.AlignVCenter
        icon.name: row.muted ? "mingcute-volume-off-fill" : "mingcute-volume-fill"
        icon.color: row.muted ? Theme.textFaint : Theme.text
        icon.width: 16
        icon.height: 16
        display: PlasmaComponents3.AbstractButton.IconOnly
        text: row.muted ? i18nd("plasma_applet_org.kde.plasma.volume", "Unmute") : i18nd("plasma_applet_org.kde.plasma.volume", "Mute")
        onClicked: row.muteToggled()

        PlasmaComponents3.ToolTip { text: parent.text }
    }
}
