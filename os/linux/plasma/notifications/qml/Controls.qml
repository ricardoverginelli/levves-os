// The bottom of the Leaves panel, under the notifications: the volume mixer
// (Applications / Devices) and a brightness slider per monitor.
// Volume and brightness come from the same QML modules as Plasma's own applets.
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.volume
import org.kde.plasma.private.brightnesscontrolplugin

import "../global" as Leaves

ColumnLayout {
    id: controls

    // Applications first (the default tab), then Devices
    property int tab: 0

    spacing: 0

    // ── Models ───────────────────────────────────────────────────────────
    // Same filters as Plasma's volume applet: no virtual streams, no event sounds
    PulseObjectFilterModel {
        id: streams
        filters: [
            { role: "VirtualStream", value: false },
            { role: "Client", value: client => client.name !== "libcanberra" },
        ]
        sourceModel: SinkInputModel {}
    }
    PulseObjectFilterModel {
        id: outputs
        filterOutInactiveDevices: true
        filterVirtualDevices: true
        sourceModel: SinkModel {}
    }
    PulseObjectFilterModel {
        id: inputs
        filterOutInactiveDevices: true
        filterVirtualDevices: true
        sourceModel: SourceModel {}
    }
    ScreenBrightnessControl {
        id: brightness
        isSilent: true  // no OSD while dragging here
    }

    // DESIGN.md spacing: 24px between sections (a 1px line in the middle),
    // 12px from a section's title to its content, 8px between rows
    component Separator: Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 12
        Layout.bottomMargin: 12
        implicitHeight: 1
        color: Leaves.Palette.border
    }

    component SectionTitle: PlasmaComponents3.Label {
        Layout.fillWidth: true
        font.pointSize: 11
        font.weight: Font.Medium
        textFormat: Text.PlainText
    }

    component SectionLabel: PlasmaComponents3.Label {
        Layout.fillWidth: true
        font.pointSize: 9
        color: Kirigami.Theme.disabledTextColor
        textFormat: Text.PlainText
    }

    // Applications / Devices as a segmented control: raised track, the current one on top
    component Tab: PlasmaComponents3.AbstractButton {
        id: tabButton
        required property int index
        implicitWidth: label.implicitWidth + 24
        implicitHeight: 28
        hoverEnabled: true
        onClicked: controls.tab = index
        contentItem: PlasmaComponents3.Label {
            id: label
            text: tabButton.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: controls.tab === tabButton.index || tabButton.hovered
                ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuint } }
        }
        background: Rectangle {
            radius: 4  // inside the 4px track, never below 4
            color: controls.tab === tabButton.index ? Leaves.Palette.surface : "transparent"
            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuint } }
        }
    }

    function volumeTo(model) {
        // Past 100% only when something already set it there
        return Math.max(PulseAudio.NormalVolume, model.Volume);
    }

    function streamName(model) {
        if (model.Client && model.Client.name && model.Client.name !== "pipewire-media-session") {
            return model.Client.name;
        }
        return model.Name || i18nd("plasma_applet_org.kde.plasma.volume", "Stream name not found");
    }

    Separator {}

    // ── Volume ───────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        SectionTitle { text: i18nd("plasma_applet_org.kde.plasma.volume", "Volume") }

        // Applications / Devices
        Rectangle {
            implicitWidth: tabs.implicitWidth + 4
            implicitHeight: 32
            radius: 4  // DESIGN.md: small control
            color: Leaves.Palette.raised

            RowLayout {
                id: tabs
                anchors.fill: parent
                anchors.margins: 2
                spacing: 2
                Tab { index: 0; text: i18nd("plasma_applet_org.kde.plasma.volume", "Applications") }
                Tab { index: 1; text: i18nd("plasma_applet_org.kde.plasma.volume", "Devices") }
            }
        }
    }

    Item {
        id: pages
        Layout.fillWidth: true
        Layout.topMargin: 12
        implicitHeight: controls.tab === 0 ? appsPage.implicitHeight : devicesPage.implicitHeight

        ColumnLayout {
            id: appsPage
            width: parent.width
            spacing: 8
            opacity: controls.tab === 0 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuint } }

            Repeater {
                model: streams
                SliderRow {
                    required property var model
                    Layout.fillWidth: true
                    text: controls.streamName(model)
                    iconSource: model.IconName || "mingcute-music-2-fill"
                    from: PulseAudio.MinimalVolume
                    normal: PulseAudio.NormalVolume
                    to: controls.volumeTo(model)
                    value: model.Volume
                    muted: model.Muted
                    mutable: true
                    onMoved: value => { model.Volume = value; model.Muted = value === 0; }
                    onMuteToggled: model.Muted = !model.Muted
                }
            }
            PlasmaComponents3.Label {
                visible: streams.count === 0
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: i18nd("plasma_applet_org.kde.plasma.volume", "No applications playing or recording audio")
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.Wrap
            }
        }

        ColumnLayout {
            id: devicesPage
            width: parent.width
            spacing: 8
            opacity: controls.tab === 1 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuint } }

            SectionLabel { text: i18nd("plasma_applet_org.kde.plasma.volume", "Output Devices"); visible: outputs.count > 0 }
            Repeater {
                model: outputs
                SliderRow {
                    required property var model
                    Layout.fillWidth: true
                    text: model.Description
                    iconSource: "mingcute-headphone-fill"
                    from: PulseAudio.MinimalVolume
                    normal: PulseAudio.NormalVolume
                    to: controls.volumeTo(model)
                    value: model.Volume
                    muted: model.Muted
                    mutable: true
                    selectable: outputs.count > 1
                    selected: model.PulseObject.default
                    onMoved: value => { model.Volume = value; model.Muted = value === 0; }
                    onMuteToggled: model.Muted = !model.Muted
                    onSelectRequested: model.PulseObject.default = true
                }
            }
            SectionLabel {
                text: i18nd("plasma_applet_org.kde.plasma.volume", "Input Devices")
                visible: inputs.count > 0
                Layout.topMargin: 8
            }
            Repeater {
                model: inputs
                SliderRow {
                    required property var model
                    Layout.fillWidth: true
                    text: model.Description
                    iconSource: "mingcute-mic-fill"
                    from: PulseAudio.MinimalVolume
                    normal: PulseAudio.NormalVolume
                    to: controls.volumeTo(model)
                    value: model.Volume
                    muted: model.Muted
                    mutable: true
                    selectable: inputs.count > 1
                    selected: model.PulseObject.default
                    onMoved: value => { model.Volume = value; model.Muted = value === 0; }
                    onMuteToggled: model.Muted = !model.Muted
                    onSelectRequested: model.PulseObject.default = true
                }
            }
        }
    }

    // ── Brightness ───────────────────────────────────────────────────────
    Separator { visible: brightness.isBrightnessAvailable }

    SectionTitle {
        visible: brightness.isBrightnessAvailable
        text: i18nd("plasma_applet_org.kde.plasma.brightness", "Brightness")
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 12
        spacing: 8
        visible: brightness.isBrightnessAvailable

        Repeater {
            model: brightness.displays
            SliderRow {
                required property string displayName
                required property string label
                required property int brightness
                required property int maxBrightness
                Layout.fillWidth: true
                text: label
                iconSource: "mingcute-sun-fill"
                to: maxBrightness
                value: brightness
                onMoved: value => controls.brightnessControl.setBrightness(displayName, Math.round(value))
            }
        }
    }
    readonly property alias brightnessControl: brightness
}
