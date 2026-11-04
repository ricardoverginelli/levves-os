// Compact perf meter: CPU 31 69°  GPU 99 79°  RAM 78  SSD 9  NET ↓2.4M ↑96K
// The Levves top bar (design/DESIGN.md): caps labels in text-muted, serif readings in text,
// warning from 70 and critical from 85.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.ksysguard.sensors as Sensors
import Levves

import "../../../../../leaves"
import "../../../../../leaves/bus.js" as LeavesBus

PlasmoidItem {
    id: root

    readonly property int warnAt: 70
    readonly property int critAt: 85

    // Spacing on the 4px grid: 4 inside a metric, 16 between metrics
    readonly property int edgeMargin: Theme.space12
    readonly property int innerGap: Theme.space4
    readonly property int groupGap: Theme.space16

    preferredRepresentation: fullRepresentation
    fullRepresentation: Item {
        Layout.minimumWidth: row.implicitWidth + root.edgeMargin
        Layout.preferredWidth: Layout.minimumWidth
        Layout.fillHeight: true

        // While the network popup is open, the reading gets the accent line the
        // tray draws under an open item (shared/ActiveLine.qml)
        Item {
            x: row.x + network.x - root.groupGap / 2
            width: network.width + root.groupGap
            height: parent.height

            ActiveLine { active: network.leavesPopupOpen }
        }

        RowLayout {
            id: row
            x: root.edgeMargin
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.groupGap

            Metric { label: "CPU"; usageId: "cpu/all/usage"; tempId: "cpu/all/maximumTemperature" }
            Metric { label: "GPU"; usageId: "gpu/all/usage"; tempId: "gpu/gpu0/temperature" }
            Metric { label: "RAM"; usageId: "memory/physical/usedPercent" }
            Metric { label: "SSD"; usageId: "disk/all/usedPercent" }
            NetworkMetric { id: network }
        }
    }

    function levelColor(value) {
        if (value >= critAt) return Theme.critical
        if (value >= warnAt) return Theme.warning
        return Theme.text
    }

    component Reading: Num {
        id: reading
        property real value: NaN
        property string suffix
        property string widest
        visible: !isNaN(value)
        font.pixelSize: Theme.typeSizeBody  // the bar's readings, a step under inline numbers
        text: Math.round(value) + suffix
        color: root.levelColor(value)
        // Reserve room for a two-digit value so the bar doesn't shift as
        // numbers change; left-aligned so the label-value gap stays 4px
        Layout.minimumWidth: widestMetrics.advanceWidth
        TextMetrics { id: widestMetrics; font: reading.font; text: reading.widest }
    }

    component Metric: RowLayout {
        property string label
        property string usageId
        property string tempId

        spacing: root.innerGap

        Sensors.Sensor { id: usage; sensorId: usageId; updateRateLimit: 2000 }
        Sensors.Sensor { id: temp; sensorId: tempId; updateRateLimit: 2000 }

        Caps { text: label }
        Reading { value: usage.value ?? NaN; widest: "00" }
        Reading { value: tempId ? (temp.value ?? NaN) : NaN; suffix: "°"; widest: "00°" }
    }

    // Download and upload for all interfaces as one reading, e.g. "↓2.4M ↑96K" (bytes per second).
    // Hovering or clicking it opens the network popup below the reading: the tray
    // in the same bar keeps the network item out of sight and opens it when asked
    // over the Leaves bus (shared/bus.js)
    component NetworkMetric: RowLayout {
        id: networkMetric
        // Set by the tray while its popup is open under this reading
        property bool leavesPopupOpen: false
        property bool leavesPopupHovered: false

        function setPopup(expanded) {
            LeavesBus.call("network", Window.window, { expanded: expanded, anchor: networkMetric })
        }

        spacing: root.innerGap

        TapHandler { onTapped: networkMetric.setPopup(!networkMetric.leavesPopupOpen) }
        HoverHandler { id: networkHover; cursorShape: Qt.PointingHandCursor }
        HoverOpener {
            triggerHovered: networkHover.hovered
            popupHovered: networkMetric.leavesPopupHovered
            open: networkMetric.leavesPopupOpen
            bar: networkMetric.Window.window
            onOpenRequested: networkMetric.setPopup(true)
            onCloseRequested: networkMetric.setPopup(false)
        }

        Sensors.Sensor { id: down; sensorId: "network/all/download"; updateRateLimit: 2000 }
        Sensors.Sensor { id: up; sensorId: "network/all/upload"; updateRateLimit: 2000 }

        Caps { text: "Net" }
        Num {
            id: rate
            readonly property string muted: Theme.textMuted
            visible: !isNaN(down.value ?? NaN)
            font.pixelSize: Theme.typeSizeBody
            textFormat: Text.StyledText
            text: `<font color="${muted}">↓</font>${root.formatRate(down.value)} <font color="${muted}">↑</font>${root.formatRate(up.value ?? 0)}`
            // Room for a typical reading so the bar doesn't shift; only 100-999K widens it a little
            Layout.minimumWidth: rateMetrics.advanceWidth
            TextMetrics { id: rateMetrics; font: rate.font; text: "↓99K ↑99K" }
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
