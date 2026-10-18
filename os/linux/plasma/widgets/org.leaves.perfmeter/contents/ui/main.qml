// Compact perf meter: [cpu] 31% 69°  [monitor] 99% 79°  [ram] 78%  [drive] 9%  [wifi] ↓2.4M ↑96K
// Each component is a MingCute icon (DESIGN.md Icons). Colors come from the
// Plasma theme: icon/arrows = muted text, value = text, warning >= 70, critical >= 85.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
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

            Metric { label: "CPU"; icon: "leaves-cpu"; usageId: "cpu/all/usage"; tempId: "cpu/all/maximumTemperature" }
            Metric { label: "GPU"; icon: "mingcute-monitor-fill"; usageId: "gpu/all/usage"; tempId: "gpu/gpu0/temperature" }
            Metric { label: "RAM"; icon: "leaves-ram"; usageId: "memory/physical/usedPercent" }
            Metric { label: "SSD"; icon: "mingcute-server-2-fill"; usageId: "disk/all/usedPercent" }
            NetworkMetric {}
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

    // Component icon in the muted label color; the name shows as a tooltip
    component MetricIcon: Kirigami.Icon {
        property string label
        implicitWidth: 16
        implicitHeight: 16
        isMask: true
        color: Kirigami.Theme.disabledTextColor

        HoverHandler { id: hover }
        PlasmaComponents.ToolTip {
            text: parent.label
            visible: hover.hovered
        }
    }

    component Metric: RowLayout {
        property string label
        property string icon
        property string usageId
        property string tempId

        spacing: root.innerGap

        Sensors.Sensor { id: usage; sensorId: usageId; updateRateLimit: 2000 }
        Sensors.Sensor { id: temp; sensorId: tempId; updateRateLimit: 2000 }

        MetricIcon { source: icon; label: parent.label }
        Reading { value: usage.value ?? NaN; suffix: "%"; widest: "00%" }
        Reading { value: tempId ? (temp.value ?? NaN) : NaN; suffix: "°"; widest: "00°" }
    }

    // Download and upload for all interfaces as one reading, e.g. "↓2.4M ↑96K" (bytes per second)
    component NetworkMetric: RowLayout {
        spacing: root.innerGap

        Sensors.Sensor { id: down; sensorId: "network/all/download"; updateRateLimit: 2000 }
        Sensors.Sensor { id: up; sensorId: "network/all/upload"; updateRateLimit: 2000 }

        MetricIcon { source: "mingcute-wifi-fill"; label: "Network" }
        Text {
            readonly property string muted: Kirigami.Theme.disabledTextColor
            visible: !isNaN(down.value ?? NaN)
            textFormat: Text.StyledText
            text: `<font color="${muted}">↓</font>${root.formatRate(down.value)} <font color="${muted}">↑</font>${root.formatRate(up.value ?? 0)}`
            color: Kirigami.Theme.textColor
            font: root.meterFont
            // Room for a typical reading so the bar doesn't shift; only 100-999K widens it a little
            Layout.minimumWidth: rateMetrics.advanceWidth
            TextMetrics { id: rateMetrics; font: root.meterFont; text: "↓99K ↑99K" }
        }
    }

    // 1000 KiB/s and up switch to MiB/s, with one decimal below 10
    function formatRate(bytes) {
        const kib = bytes / 1024
        if (kib < 1000) return Math.round(kib) + "K"
        const mib = kib / 1024
        return (mib < 10 ? mib.toFixed(1) : Math.round(mib)) + "M"
    }
}
