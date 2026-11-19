// The clock's popup: a compact month calendar on the left, the agenda on the
// right. The agenda lists the next 15 days; clicking a day in the calendar shows
// that day's events instead, and clicking it again (or Today) goes back.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import org.kde.plasma.plasmoid
import org.kde.plasma.workspace.calendar as PlasmaCalendar
import org.kde.kirigami as Kirigami
import Levves
import "../../../../../leaves"

Item {
    id: popup

    required property var clock
    required property ListModel agenda
    required property bool shown
    readonly property alias hovered: hover.hovered

    // Two group boxes side by side (design/DESIGN.md Pieces), 12px from the frame (the style adds 4)
    readonly property int pad: Theme.space12
    readonly property int sectionGap: Theme.space12
    readonly property int cellWidth: 36
    readonly property int cellHeight: 32
    readonly property int toolbarHeight: Theme.sizeKey
    readonly property int agendaWidth: 300

    readonly property color mutedColor: Theme.textMuted
    readonly property int houseCurve: Easing.OutQuint
    readonly property int hoverDuration: Theme.durationHover

    // Calendar colors are held to the palette: each Google color becomes the
    // nearest-hued of info, success, warning, critical, magenta and cyan
    readonly property var tints: [Theme.info, Theme.success, Theme.warning, Theme.critical,
                                  Theme.terminalMagenta, Theme.terminalCyan]
    function tint(color) {
        if (!color)
            return mutedColor
        const c = Qt.lighter(color, 1.0)
        if (c.hslSaturation < 0.12 || c.hslHue < 0)
            return mutedColor
        let best = tints[0], bestDistance = 2
        for (const t of tints) {
            const d = Math.abs(Qt.lighter(t, 1.0).hslHue - c.hslHue)
            const distance = Math.min(d, 1 - d)
            if (distance < bestDistance) {
                best = t
                bestDistance = distance
            }
        }
        return best
    }

    // The day picked in the calendar; null shows the upcoming days
    property var selectedDay: null
    function sameDay(a, b) {
        return !!a && !!b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
    }
    function select(day) {
        selectedDay = sameDay(day, selectedDay) ? null : day
        rebuildSelected()
    }
    function goToToday() {
        selectedDay = null
        grid.resetToToday()
    }
    onShownChanged: if (!shown) goToToday()

    readonly property bool viewingThisMonth: grid.year === clock.today.getFullYear() && grid.month === clock.today.getMonth() + 1

    function dayLabel(day) {
        if (sameDay(day, clock.today))
            return "Today"
        const tomorrow = new Date(clock.today.getFullYear(), clock.today.getMonth(), clock.today.getDate() + 1)
        if (sameDay(day, tomorrow))
            return "Tomorrow"
        return Qt.formatDate(day, "dddd d MMM")
    }
    function timeText(date) {
        return Qt.formatTime(date, Qt.locale().timeFormat(Locale.ShortFormat))
    }
    // "All day", "9:00 AM – 10:00 AM", "Now · until 10:00 AM", "Until 2:00 AM"
    // (began the day before), "From 11:00 PM" (ends the day after)
    function whenText(e) {
        const dayStart = e.day
        const dayEnd = new Date(dayStart.getFullYear(), dayStart.getMonth(), dayStart.getDate() + 1)
        if (e.allDay) {
            const lastDay = new Date(e.end.getFullYear(), e.end.getMonth(), e.end.getDate() - 1)
            return lastDay > dayStart ? "All day · until " + Qt.formatDate(lastDay, "ddd d MMM") : "All day"
        }
        const rightNow = clock.now
        if (e.start <= rightNow && rightNow < e.end)
            return "Now · until " + timeText(e.end)
        const startsBefore = e.start < dayStart
        const endsAfter = e.end > dayEnd
        if (startsBefore && endsAfter)
            return "All day"
        if (startsBefore)
            return "Until " + timeText(e.end)
        if (endsAfter)
            return "From " + timeText(e.start)
        return timeText(e.start) + " – " + timeText(e.end)
    }

    // The selected day's events, read from the calendar's own model (it covers
    // every day the calendar shows)
    ListModel { id: selectedEvents }
    function rebuildSelected() {
        selectedEvents.clear()
        if (selectedDay)
            for (const e of clock.eventsOn(selectedDay, grid.daysModel))
                selectedEvents.append(e)
    }

    readonly property int gridWidth: 7 * cellWidth
    readonly property int boxPad: Theme.space12  // a group box's body to its edge
    Layout.preferredWidth: pad + gridWidth + 2 * boxPad + 2 + sectionGap + agendaWidth + pad
    Layout.minimumWidth: Layout.preferredWidth
    Layout.maximumWidth: Layout.preferredWidth
    Layout.preferredHeight: pad + Theme.sizeGroupHeader + boxPad + toolbarHeight + 8 + 20 + 4 + 6 * cellHeight + boxPad + 2 + pad
    Layout.minimumHeight: Layout.preferredHeight
    Layout.maximumHeight: Layout.preferredHeight

    HoverHandler { id: hover }

    PlasmaCalendar.EventPluginsManager {
        id: gridPlugins
        enabledPlugins: ["pimevents"]
    }
    PlasmaCalendar.Calendar {
        id: grid
        days: 7
        weeks: 6
        firstDayOfWeek: Qt.locale().firstDayOfWeek
        today: popup.clock.today
        Component.onCompleted: daysModel.setPluginsManager(gridPlugins)
    }
    Connections {
        target: grid.daysModel
        function onAgendaUpdated() { Qt.callLater(popup.rebuildSelected) }
        function onModelReset() { Qt.callLater(popup.rebuildSelected) }
    }

    // A small key with a MingCute icon (the month's arrows)
    component IconKey: Key {
        id: button
        property string iconName
        implicitWidth: Theme.sizeKey
        leftPadding: 0
        rightPadding: 0
        focusPolicy: Qt.NoFocus
        contentItem: Item {
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 16
                height: 16
                source: button.iconName
                isMask: true
                color: Theme.text
            }
        }
    }

    // ── Calendar ────────────────────────────────────────────────────────
    GroupBox {
        id: calendarBox
        x: popup.pad
        y: popup.pad
        width: popup.gridWidth + 2 * popup.boxPad + 2
        height: popup.height - 2 * popup.pad
        padding: popup.boxPad
        title: Qt.locale().standaloneMonthName(grid.month - 1)
        value: grid.year

        ColumnLayout {
            width: popup.gridWidth
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: popup.toolbarHeight
                spacing: 3

                // Back to this month (and the upcoming list)
                Key {
                    visible: !popup.viewingThisMonth || popup.selectedDay !== null
                    text: "Today"
                    focusPolicy: Qt.NoFocus
                    onClicked: popup.goToToday()
                }
                Item { Layout.fillWidth: true }
                IconKey {
                    iconName: "mingcute-left-fill"
                    onClicked: grid.previousMonth()
                }
                IconKey {
                    iconName: "mingcute-right-fill"
                    onClicked: grid.nextMonth()
                }
            }

            Item { Layout.preferredHeight: 8 }

            // Weekday initials, in the locale's order
            Row {
                Layout.preferredHeight: 20
                Repeater {
                    model: 7
                    Caps {
                        required property int index
                        width: popup.cellWidth
                        height: 20
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.locale().dayName((grid.firstDayOfWeek + index) % 7, Locale.NarrowFormat)
                    }
                }
            }

            Item { Layout.preferredHeight: 4 }

            Grid {
                id: days
                columns: 7

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        if (event.angleDelta.y > 0)
                            grid.previousMonth()
                        else if (event.angleDelta.y < 0)
                            grid.nextMonth()
                    }
                }

                Repeater {
                    model: grid.daysModel

                    QQC2.AbstractButton {
                        id: cell
                        required property int dayNumber
                        required property int monthNumber
                        required property int yearNumber
                        required property bool isCurrent
                        required property var model
                        readonly property date date: new Date(yearNumber, monthNumber - 1, dayNumber)
                        readonly property bool isToday: popup.sameDay(date, popup.clock.today)
                        readonly property bool isSelected: popup.sameDay(date, popup.selectedDay)
                        readonly property bool hasEvents: (model.eventCount ?? 0) > 0

                        width: popup.cellWidth
                        height: popup.cellHeight
                        hoverEnabled: true
                        onClicked: popup.select(date)

                        // Today is outlined; the picked day is held down like a key
                        background: Item {
                            Rectangle {
                                anchors.centerIn: parent
                                width: 30
                                height: 28
                                radius: Theme.radiusKey
                                color: cell.isSelected ? Theme.wellPressed
                                     : cell.hovered ? Theme.hoverTint
                                     : "transparent"
                                border.width: cell.isToday || cell.isSelected ? 1 : 0
                                border.color: cell.isToday ? Theme.text : Theme.fieldEdge
                                Behavior on color { ColorAnimation { duration: popup.hoverDuration; easing.type: popup.houseCurve } }
                            }
                        }
                        contentItem: Item {
                            Num {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -2
                                text: cell.dayNumber
                                font.weight: cell.isToday ? Theme.typeWeightSemibold : Theme.typeWeightRegular
                                color: cell.isCurrent || cell.isToday ? Theme.text : Theme.textFaint
                            }
                            // A dot under days with events
                            Rectangle {
                                visible: cell.hasEvents
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: 9
                                width: 3
                                height: 3
                                color: cell.isCurrent ? Theme.textMuted : Theme.textFaint
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Agenda ──────────────────────────────────────────────────────────
    GroupBox {
        x: calendarBox.x + calendarBox.width + popup.sectionGap
        y: popup.pad
        width: popup.agendaWidth
        height: popup.height - 2 * popup.pad
        padding: 0
        title: popup.selectedDay ? Qt.formatDate(popup.selectedDay, "dddd d MMMM") : "Upcoming"
        value: popup.selectedDay ? "" : `${popup.clock.daysAhead} days`

        Item {
            width: popup.agendaWidth - 2
            height: popup.height - 2 * popup.pad - Theme.sizeGroupHeader - 1

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: popup.selectedDay ? selectedEvents : popup.agenda
                visible: count > 0
                spacing: 0

                // No scrollbar (the style's groove read as a stray line beside
                // the list); rows fade out at an edge with more content past it
                layer.enabled: !atYBeginning || !atYEnd
                layer.effect: GE.OpacityMask { maskSource: fade }

                // Each day a header row: its label with a hairline under it, no strip
                section.property: popup.selectedDay ? "" : "dayKey"
                section.delegate: Item {
                    required property string section
                    width: ListView.view.width
                    height: Theme.sizeGroupHeader
                    Caps {
                        x: Theme.space12
                        height: parent.height
                        text: popup.dayLabel(new Date(parent.section))
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
                }

                delegate: QQC2.AbstractButton {
                    id: row
                    required property string title
                    required property date start
                    required property date end
                    required property bool allDay
                    required property string color
                    required property date day
                    readonly property bool now: !allDay && start <= popup.clock.now && popup.clock.now < end

                    width: ListView.view.width
                    height: 44
                    hoverEnabled: true
                    onClicked: popup.clock.openDay(day)

                    background: Rectangle {
                        color: row.hovered ? Theme.hoverTint : "transparent"
                        Behavior on color { ColorAnimation { duration: popup.hoverDuration; easing.type: popup.houseCurve } }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.rowLine }
                    }
                    contentItem: RowLayout {
                        spacing: Theme.space12
                        // The calendar's color
                        Rectangle {
                            Layout.leftMargin: Theme.space12
                            Layout.preferredWidth: 3
                            Layout.preferredHeight: 28
                            color: popup.tint(row.color)
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.rightMargin: Theme.space12
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: row.title
                                elide: Text.ElideRight
                                font.family: Theme.typeFamilySans
                                font.pixelSize: Theme.typeSizeBody
                                color: Theme.text
                            }
                            // When, as a remark; an event on now reads as a plain number
                            Quiet {
                                Layout.fillWidth: true
                                text: popup.whenText(row)
                                elide: Text.ElideRight
                                font.pixelSize: Theme.typeSizeSmall + 1
                                font.italic: !row.now
                                color: row.now ? Theme.text : Theme.textMuted
                            }
                        }
                    }
                }
            }

            ScrollFade { id: fade; view: list }

            // Nothing to show: no accounts yet, or a free stretch
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 2 * Theme.space12
                visible: list.count === 0
                spacing: Theme.space12

                Quiet {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: popup.clock.accountsLoaded && popup.clock.accounts.length === 0
                        ? "No Google accounts yet"
                        : popup.selectedDay ? "Nothing on this day"
                        : `Nothing in the next ${popup.clock.daysAhead} days`
                }
                Key {
                    visible: popup.clock.accountsLoaded && popup.clock.accounts.length === 0
                    Layout.alignment: Qt.AlignHCenter
                    text: "Add an account"
                    focusPolicy: Qt.NoFocus
                    onClicked: Plasmoid.internalAction("configure").trigger()
                }
            }
        }
    }
}
