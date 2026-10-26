// The clock's popup: a compact month calendar on the left, the agenda on the
// right. The agenda lists the next 15 days; clicking a day in the calendar shows
// that day's events instead, and clicking it again (or Today) goes back.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.workspace.calendar as PlasmaCalendar
import org.kde.kirigami as Kirigami

Item {
    id: popup

    required property var clock
    required property ListModel agenda
    required property bool shown
    readonly property alias hovered: hover.hovered

    // DESIGN.md spacing: content 12px from the frame (the style adds 4),
    // 24 between the two sections with a 1px line in the middle
    readonly property int pad: 12
    readonly property int sectionGap: 24
    readonly property int cellWidth: 36
    readonly property int cellHeight: 32
    readonly property int headerHeight: 28
    readonly property int agendaWidth: 280

    // Palette (DESIGN.md Colors)
    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor
    readonly property color faintColor: "#5f6b67"
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color onAccent: Kirigami.Theme.highlightedTextColor
    readonly property color lineColor: Qt.alpha(textColor, 0.10)
    readonly property int houseCurve: Easing.OutQuint
    readonly property int hoverDuration: 150

    // Calendar colors are held to the palette: each Google color becomes the
    // nearest-hued of info, success, warning, critical, magenta and cyan
    readonly property var tints: ["#82a9c4", "#8fbf8a", "#e8cf6a", "#e0607a", "#b48cbf", "#7fbab3"]
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
    Layout.preferredWidth: pad + gridWidth + sectionGap + agendaWidth + pad
    Layout.minimumWidth: Layout.preferredWidth
    Layout.maximumWidth: Layout.preferredWidth
    Layout.preferredHeight: pad + headerHeight + 12 + 20 + 4 + 6 * cellHeight + pad
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

    // A 24px square button with a MingCute icon (DESIGN.md: small control, 4px corners)
    component IconButton: QQC2.AbstractButton {
        id: button
        property string iconName
        implicitWidth: 24
        implicitHeight: 24
        hoverEnabled: true
        background: Rectangle {
            radius: 4
            color: button.pressed ? Qt.alpha(popup.textColor, 0.10)
                 : button.hovered ? Qt.alpha(popup.textColor, 0.06) : "transparent"
            Behavior on color { ColorAnimation { duration: popup.hoverDuration; easing.type: popup.houseCurve } }
        }
        contentItem: Item {
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 16
                height: 16
                source: button.iconName
                isMask: true
                color: button.hovered ? popup.textColor : popup.mutedColor
            }
        }
    }

    // ── Calendar ────────────────────────────────────────────────────────
    ColumnLayout {
        id: calendarColumn
        x: popup.pad
        y: popup.pad
        width: popup.gridWidth
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: popup.headerHeight
            spacing: 4

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                font.pointSize: 11
                font.weight: Font.Medium
                color: popup.textColor
                elide: Text.ElideRight
                text: Qt.locale().standaloneMonthName(grid.month - 1) + " "
                      + `<font color="${popup.mutedColor}">${grid.year}</font>`
                textFormat: Text.StyledText
            }
            // Back to this month (and the upcoming list)
            QQC2.AbstractButton {
                id: todayButton
                visible: !popup.viewingThisMonth || popup.selectedDay !== null
                implicitHeight: 24
                implicitWidth: todayLabel.implicitWidth + 16
                hoverEnabled: true
                onClicked: popup.goToToday()
                background: Rectangle {
                    radius: 4
                    color: todayButton.hovered ? Qt.alpha(popup.textColor, 0.12) : Qt.alpha(popup.textColor, 0.06)
                    Behavior on color { ColorAnimation { duration: popup.hoverDuration; easing.type: popup.houseCurve } }
                }
                contentItem: Text {
                    id: todayLabel
                    text: "Today"
                    font.pointSize: 9
                    color: todayButton.hovered ? popup.textColor : popup.mutedColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            IconButton {
                iconName: "mingcute-left-fill"
                onClicked: grid.previousMonth()
            }
            IconButton {
                iconName: "mingcute-right-fill"
                onClicked: grid.nextMonth()
            }
        }

        Item { Layout.preferredHeight: 12 }

        // Weekday initials, in the locale's order
        Row {
            Layout.preferredHeight: 20
            Repeater {
                model: 7
                Text {
                    required property int index
                    width: popup.cellWidth
                    height: 20
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pointSize: 9
                    color: popup.mutedColor
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

                    background: Item {
                        Rectangle {
                            anchors.centerIn: parent
                            width: 28
                            height: 28
                            radius: 4
                            color: cell.isToday ? popup.accent
                                 : cell.isSelected ? Qt.alpha(popup.textColor, 0.12)
                                 : cell.hovered ? Qt.alpha(popup.textColor, 0.06) : "transparent"
                            Behavior on color { ColorAnimation { duration: popup.hoverDuration; easing.type: popup.houseCurve } }
                        }
                    }
                    contentItem: Item {
                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -1
                            text: cell.dayNumber
                            font.pointSize: 10
                            font.weight: cell.isToday ? Font.DemiBold : Font.Normal
                            color: cell.isToday ? popup.onAccent
                                 : cell.isCurrent ? popup.textColor : popup.faintColor
                        }
                        // A dot under days with events
                        Rectangle {
                            visible: cell.hasEvents
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 9
                            width: 4
                            height: 4
                            radius: 2
                            color: cell.isToday ? popup.onAccent
                                 : cell.isCurrent ? popup.mutedColor : popup.faintColor
                        }
                    }
                }
            }
        }
    }

    // The line between the sections
    Rectangle {
        x: popup.pad + popup.gridWidth + popup.sectionGap / 2
        y: popup.pad
        width: 1
        height: popup.height - 2 * popup.pad
        color: popup.lineColor
    }

    // ── Agenda ──────────────────────────────────────────────────────────
    ColumnLayout {
        x: popup.pad + popup.gridWidth + popup.sectionGap
        y: popup.pad
        width: popup.agendaWidth
        height: popup.height - 2 * popup.pad
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: popup.headerHeight
            spacing: 8
            Text {
                Layout.fillWidth: true
                font.pointSize: 11
                font.weight: Font.Medium
                color: popup.textColor
                elide: Text.ElideRight
                text: popup.selectedDay ? Qt.formatDate(popup.selectedDay, "dddd d MMMM") : "Upcoming"
            }
            Text {
                visible: !popup.selectedDay
                font.pointSize: 9
                color: popup.mutedColor
                text: `Next ${popup.clock.daysAhead} days`
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: popup.selectedDay ? selectedEvents : popup.agenda
                visible: count > 0
                spacing: 0
                QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded }

                section.property: popup.selectedDay ? "" : "dayKey"
                section.delegate: Text {
                    required property string section
                    width: ListView.view.width
                    height: 24
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 4
                    font.pointSize: 9
                    font.weight: Font.Medium
                    color: popup.mutedColor
                    text: popup.dayLabel(new Date(section))
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
                        radius: 6
                        color: row.hovered ? Qt.alpha(popup.textColor, 0.06) : "transparent"
                        Behavior on color { ColorAnimation { duration: popup.hoverDuration; easing.type: popup.houseCurve } }
                    }
                    contentItem: RowLayout {
                        spacing: 12
                        // The calendar's color
                        Rectangle {
                            Layout.leftMargin: 4
                            Layout.preferredWidth: 3
                            Layout.preferredHeight: 28
                            radius: 1.5
                            color: popup.tint(row.color)
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: row.title
                                elide: Text.ElideRight
                                font.pointSize: 10
                                color: popup.textColor
                            }
                            Text {
                                Layout.fillWidth: true
                                text: popup.whenText(row)
                                elide: Text.ElideRight
                                font.pointSize: 9
                                font.weight: row.now ? Font.Medium : Font.Normal
                                color: row.now ? popup.textColor : popup.mutedColor
                            }
                        }
                    }
                }
            }

            // Nothing to show: no accounts yet, or a free stretch
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width
                visible: list.count === 0
                spacing: 12

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 24
                    implicitHeight: 24
                    source: "mingcute-calendar-fill"
                    isMask: true
                    color: popup.faintColor
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.pointSize: 10
                    color: popup.mutedColor
                    text: popup.clock.accountsLoaded && popup.clock.accounts.length === 0
                        ? "No Google accounts yet"
                        : popup.selectedDay ? "Nothing on this day"
                        : `Nothing in the next ${popup.clock.daysAhead} days`
                }
                QQC2.AbstractButton {
                    id: addButton
                    visible: popup.clock.accountsLoaded && popup.clock.accounts.length === 0
                    Layout.alignment: Qt.AlignHCenter
                    implicitHeight: 28
                    implicitWidth: addLabel.implicitWidth + 24
                    hoverEnabled: true
                    onClicked: Plasmoid.internalAction("configure").trigger()
                    background: Rectangle {
                        radius: 4
                        color: addButton.hovered ? Qt.alpha(popup.textColor, 0.12) : Qt.alpha(popup.textColor, 0.06)
                        Behavior on color { ColorAnimation { duration: popup.hoverDuration; easing.type: popup.houseCurve } }
                    }
                    contentItem: Text {
                        id: addLabel
                        text: "Add an account…"
                        font.pointSize: 10
                        color: popup.textColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
