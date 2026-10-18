// Compact perf meter: "CPU 31% 69°  GPU 99% 79°  RAM 78%  SSD 9%"
// Colors come from the Plasma theme (see ../../../../DESIGN.md):
// label = muted text, value = text, warning >= 70, critical >= 85.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root

    readonly property int warnAt: 70
    readonly property int critAt: 85
    readonly property font meterFont: Qt.font({ family: Kirigami.Theme.defaultFont.family, pointSize: 9 })

    // Spacing on the DESIGN.md 4px grid: 4 inside a metric, 16 between metrics
    readonly property int edgeMargin: 12
    readonly property int innerGap: 4
    readonly property int groupGap: 16

    preferredRepresentation: fullRepresentation
    fullRepresentation: Item {
        Layout.minimumWidth: row.implicitWidth + root.edgeMargin
        Layout.preferredWidth: Layout.minimumWidth
        Layout.fillHeight: true

        RowLayout {
            id: row
            x: root.edgeMargin
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.groupGap

            Metric { label: "CPU"; usageId: "cpu/all/usage"; tempId: "cpu/all/maximumTemperature" }
            Metric { label: "GPU"; usageId: "gpu/all/usage"; tempId: "gpu/gpu0/temperature" }
            Metric { label: "RAM"; usageId: "memory/physical/usedPercent" }
            Metric { label: "SSD"; usageId: "disk/all/usedPercent" }
        }
    }

    function levelColor(value) {
        if (value >= critAt) return Kirigami.Theme.negativeTextColor
        if (value >= warnAt) return Kirigami.Theme.neutralTextColor
        return Kirigami.Theme.textColor
    }

    component Reading: Text {
        property real value: NaN
        property string suffix
        property string widest
        visible: !isNaN(value)
        text: Math.round(value) + suffix
        color: root.levelColor(value)
        font: root.meterFont
        // Reserve room for a two-digit value so the bar doesn't shift as
        // numbers change; left-aligned so the label-value gap stays 4px
        Layout.minimumWidth: widestMetrics.advanceWidth
        TextMetrics { id: widestMetrics; font: root.meterFont; text: widest }
    }

    component Metric: RowLayout {
        property string label
        property string usageId
        property string tempId

        spacing: root.innerGap

        Sensors.Sensor { id: usage; sensorId: usageId; updateRateLimit: 2000 }
        Sensors.Sensor { id: temp; sensorId: tempId; updateRateLimit: 2000 }

        Text {
            text: label
            color: Kirigami.Theme.disabledTextColor
            font: root.meterFont
        }
        Reading { value: usage.value ?? NaN; suffix: "%"; widest: "00%" }
        Reading { value: tempId ? (temp.value ?? NaN) : NaN; suffix: "°"; widest: "00°" }
    }
}
