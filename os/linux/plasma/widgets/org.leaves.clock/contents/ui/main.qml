// Weekday, date and time for the top bar: "Sun 25 Oct  9:45 PM". Hovering it
// opens the popup (CalendarPopup.qml): a month calendar on the left and the next
// 15 days of events on the right.
//
// Events come from Akonadi through Plasma's PIM events plugin, the same source
// as the stock clock, limited to Google accounts: the settings page
// (ConfigCalendars.qml) adds and removes accounts and picks their calendars.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.workspace.calendar as PlasmaCalendar
import org.kde.kirigami as Kirigami

import "../../../../../leaves"

PlasmoidItem {
    id: root

    readonly property int daysAhead: 15
    readonly property font barFont: Qt.font({ family: Kirigami.Theme.defaultFont.family, pointSize: 9, weight: Font.DemiBold })

    // The clock ticks on the minute
    property date now: new Date()
    readonly property date today: new Date(now.getFullYear(), now.getMonth(), now.getDate())
    Timer {
        running: true
        repeat: true
        interval: 60000 - root.now.getSeconds() * 1000 - root.now.getMilliseconds() + 50
        onTriggered: root.now = new Date()
    }
    onTodayChanged: Qt.callLater(rebuildAgenda)

    // Hover popups have no tooltips (TODO.md Top bar)
    toolTipMainText: ""
    toolTipSubText: ""

    HoverOpener {
        id: hoverOpener
        open: root.expanded
        onOpenRequested: root.expanded = true
        onCloseRequested: root.expanded = false
    }

    // The Gmail accounts (contents/code/accounts.sh), re-read when the popup opens
    property var accounts: []
    property bool accountsLoaded: false
    readonly property string accountsHelper: Qt.resolvedUrl("../code/accounts.sh").toString().replace("file://", "")
    function runAccounts(args) {
        executable.connectSource("sh '" + accountsHelper.replace(/'/g, "'\\''") + "' " + args)
    }
    P5Support.DataSource {
        id: executable
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source.endsWith(" list")) {
                root.accounts = data.stdout.split("\n").filter(line => line).map(line => {
                    const [id, name] = line.split("\t")
                    return { id: id, name: name }
                })
                root.accountsLoaded = true
            }
        }
    }
    Component.onCompleted: runAccounts("list")
    onExpandedChanged: () => {
        if (root.expanded) {
            runAccounts("list")
            rebuildAgenda()
        }
    }

    // The agenda reads events from a calendar of its own, always on today's month
    // and long enough (9 weeks) to reach 15 days past the month's last day
    PlasmaCalendar.EventPluginsManager {
        id: agendaPlugins
        enabledPlugins: ["pimevents"]
    }
    PlasmaCalendar.Calendar {
        id: agendaCalendar
        days: 7
        weeks: 9
        firstDayOfWeek: Qt.locale().firstDayOfWeek
        today: root.today
        displayedDate: root.today
        Component.onCompleted: daysModel.setPluginsManager(agendaPlugins)
    }
    Connections {
        target: agendaCalendar.daysModel
        function onAgendaUpdated() { Qt.callLater(root.rebuildAgenda) }
        function onModelReset() { Qt.callLater(root.rebuildAgenda) }
        function onDataChanged() { Qt.callLater(root.rebuildAgenda) }
    }

    // One entry per event and day it falls on, from now to daysAhead days out;
    // today's finished events are left out
    ListModel { id: agendaModel }
    function rebuildAgenda() {
        const rightNow = new Date()
        const rows = []
        for (let i = 0; i < daysAhead; i++) {
            const day = new Date(today.getFullYear(), today.getMonth(), today.getDate() + i)
            rows.push(...eventsOn(day, agendaCalendar.daysModel)
                .filter(e => i > 0 || e.allDay || e.end > rightNow)
                .map(e => Object.assign(e, { dayKey: day.toISOString() })))
        }
        agendaModel.clear()
        for (const row of rows)
            agendaModel.append(row)
    }

    // A day's events from a calendar's model, all-day ones first, then by start
    function eventsOn(day, daysModel) {
        const seen = new Set()
        const list = []
        for (const e of daysModel.eventsForDate(day)) {
            const key = e.title + "|" + e.startDateTime
            if (e.isMinor || seen.has(key))
                continue
            seen.add(key)
            list.push({
                title: e.title || "(No title)",
                start: new Date(e.startDateTime),
                end: new Date(e.endDateTime),
                allDay: e.isAllDay,
                color: String(e.eventColor || ""),
                day: day,
            })
        }
        list.sort((a, b) => (b.allDay - a.allDay) || (a.start - b.start))
        return list
    }

    // Google Calendar's day view, in the browser
    function openDay(day) {
        Qt.openUrlExternally(`https://calendar.google.com/calendar/r/day/${day.getFullYear()}/${day.getMonth() + 1}/${day.getDate()}`)
        expanded = false
    }

    preferredRepresentation: compactRepresentation
    compactRepresentation: MouseArea {
        id: compact

        readonly property int sidePadding: 8
        Layout.minimumWidth: row.implicitWidth + 2 * sidePadding
        Layout.preferredWidth: Layout.minimumWidth
        Layout.fillHeight: true
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        Binding { target: hoverOpener; property: "bar"; value: compact.Window.window }
        Binding { target: hoverOpener; property: "triggerHovered"; value: compact.containsMouse }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 8
            Text {
                font: root.barFont
                color: Kirigami.Theme.textColor
                text: Qt.formatDate(root.now, "ddd d MMM")
            }
            Text {
                font: root.barFont
                color: Kirigami.Theme.textColor
                text: Qt.formatTime(root.now, Qt.locale().timeFormat(Locale.ShortFormat))
            }
        }
    }

    fullRepresentation: CalendarPopup {
        id: popup
        clock: root
        agenda: agendaModel
        shown: root.expanded

        Binding { target: hoverOpener; property: "popupHovered"; value: popup.hovered }
    }
}
