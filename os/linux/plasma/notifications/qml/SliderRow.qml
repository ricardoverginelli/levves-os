// One row of the Leaves panel: icon, name, slider, value, and an optional mute button.
// Used for app streams, audio devices and monitors (Controls.qml).
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

import "../global" as Leaves

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
        color: Kirigami.Theme.disabledTextColor
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4  // DESIGN.md: a label and its control

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Default-device marker: filled when selected
            Rectangle {
                visible: row.selectable
                implicitWidth: 8
                implicitHeight: 8
                radius: 4
                color: row.selected ? Leaves.Palette.text : "transparent"
                border.width: row.selected ? 0 : 1
                border.color: Leaves.Palette.textFaint
            }

            PlasmaComponents3.Label {
                id: label
                Layout.fillWidth: true
                elide: Text.ElideRight
                textFormat: Text.PlainText
                color: row.muted ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor

                TapHandler {
                    enabled: row.selectable && !row.selected
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onTapped: row.selectRequested()
                }
            }

            PlasmaComponents3.Label {
                Layout.minimumWidth: 32
                horizontalAlignment: Text.AlignRight
                text: Math.round(100 * (slider.pressed ? slider.value : row.value) / row.normal) + "%"
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: 9
            }
        }

        T.Slider {
            id: slider
            Layout.fillWidth: true
            implicitHeight: 16
            from: row.from
            to: row.to
            stepSize: (row.normal - row.from) / 100
            enabled: !row.muted || row.mutable
            hoverEnabled: true
            onMoved: row.moved(value)

            Binding on value {
                when: !slider.pressed
                value: row.value
            }

            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + (slider.availableHeight - height) / 2
                width: slider.availableWidth
                height: 4
                radius: 2
                color: Leaves.Palette.raised

                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: 2
                    color: row.muted ? Leaves.Palette.textFaint : Leaves.Palette.textMuted
                }
                // Where 100% is, when the slider goes past it
                Rectangle {
                    visible: row.normal < row.to
                    x: (row.normal - row.from) / (row.to - row.from) * parent.width - 1
                    y: -2
                    width: 2
                    height: 8
                    radius: 1
                    color: Leaves.Palette.border
                }
            }

            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + (slider.availableHeight - height) / 2
                width: 12
                height: 12
                radius: 6
                // The one accent: the handle you're dragging
                color: slider.pressed ? Leaves.Palette.accent
                    : slider.hovered ? Leaves.Palette.text : Leaves.Palette.textMuted
                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuint } }
            }
        }
    }

    PlasmaComponents3.ToolButton {
        visible: row.mutable
        Layout.alignment: Qt.AlignVCenter
        icon.name: row.muted ? "mingcute-volume-off-fill" : "mingcute-volume-fill"
        icon.color: row.muted ? Leaves.Palette.textFaint : Kirigami.Theme.textColor
        icon.width: 16
        icon.height: 16
        display: PlasmaComponents3.AbstractButton.IconOnly
        text: row.muted ? i18nd("plasma_applet_org.kde.plasma.volume", "Unmute") : i18nd("plasma_applet_org.kde.plasma.volume", "Mute")
        onClicked: row.muteToggled()

        PlasmaComponents3.ToolTip { text: parent.text }
    }
}
