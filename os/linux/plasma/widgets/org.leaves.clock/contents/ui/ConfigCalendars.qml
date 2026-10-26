// Settings page: the Gmail accounts the agenda reads from, and which of their
// calendars it shows. Accounts are Akonadi Google resources (accounts.sh);
// the calendar picks go to the PIM events plugin's own settings, so they apply
// at once. Calendars of anything that isn't a Google account are kept off.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils
import org.kde.kitemmodels
import org.kde.plasma.PimCalendars
import org.kde.plasma.plasma5support as P5Support

KCMUtils.SimpleKCM {
    id: page

    // The Google resources: [{ id, name }]
    property var accounts: []
    // The calendar tree flattened: [{ name, calendars: [{ id, name, checked }] }],
    // one entry per top-level collection (an account's root carries its name)
    property var groups: []

    readonly property string helper: Qt.resolvedUrl("../code/accounts.sh").toString().replace("file://", "")
    function run(args) {
        executable.connectSource("sh '" + helper.replace(/'/g, "'\\''") + "' " + args)
    }
    P5Support.DataSource {
        id: executable
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source.endsWith(" list")) {
                page.accounts = data.stdout.split("\n").filter(line => line).map(line => {
                    const [id, name] = line.split("\t")
                    return { id: id, name: name }
                })
                page.keepToGoogle()
            } else {
                refresh.restart()
            }
        }
    }
    // Sign-in finishes in Akonadi's own dialog, so look again for a while
    Timer {
        id: refresh
        interval: 2000
        repeat: true
        property int runs: 0
        onTriggered: {
            page.run("list")
            if (++runs >= 30) {
                runs = 0
                stop()
            }
        }
    }
    Component.onCompleted: run("list")

    function signedIn(account) {
        return !account.name.startsWith("akonadi_google_resource") && !account.name.includes("(Not configured)")
    }
    // "Google Groupware (me@gmail.com)" → "me@gmail.com"
    function address(account) {
        const match = account.name.match(/\(([^()]+@[^()]+)\)$/)
        return match ? match[1] : account.name
    }
    function ownsGroup(account, group) {
        return group.name === account.name || group.name === address(account)
    }
    function calendarsOf(account) {
        const group = groups.find(g => ownsGroup(account, g))
        return group ? group.calendars : []
    }

    PimCalendarsModel { id: calendarModel }
    KDescendantsProxyModel {
        id: flatCalendars
        model: calendarModel
    }
    Instantiator {
        id: rows
        model: flatCalendars
        delegate: QtObject {
            required property int index
            required property int collectionId
            required property string name
            required property bool isChecked
            required property bool isEnabled
            required property int kDescendantLevel
            onIsCheckedChanged: Qt.callLater(page.rebuildGroups)
        }
        onObjectAdded: Qt.callLater(page.rebuildGroups)
        onObjectRemoved: Qt.callLater(page.rebuildGroups)
    }
    function rebuildGroups() {
        const list = []
        for (let i = 0; i < rows.count; i++) {
            const row = rows.objectAt(i)
            if (!row)
                continue
            if (row.kDescendantLevel <= 1)
                list.push({ name: row.name, calendars: [] })
            if (row.isEnabled && list.length)
                list[list.length - 1].calendars.push({ id: row.collectionId, name: row.name, checked: row.isChecked })
        }
        groups = list
        keepToGoogle()
    }
    // Gmail only: calendars outside the Google accounts are switched off
    function keepToGoogle() {
        let changed = false
        for (const group of groups)
            if (!accounts.some(a => ownsGroup(a, group)))
                for (const calendar of group.calendars)
                    if (calendar.checked) {
                        calendarModel.setChecked(calendar.id, false)
                        changed = true
                    }
        if (changed)
            calendarModel.saveConfig()
    }
    function setChecked(id, checked) {
        calendarModel.setChecked(id, checked)
        calendarModel.saveConfig()
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "The clock's agenda shows events from these Google accounts. Adding one opens Google's sign-in."
        }

        Repeater {
            model: page.accounts

            ColumnLayout {
                id: account
                required property var modelData
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Separator { Layout.fillWidth: true }

                RowLayout {
                    Layout.fillWidth: true
                    Kirigami.Icon {
                        source: "mingcute-mail-fill"
                        isMask: true
                        color: Kirigami.Theme.textColor
                        implicitWidth: 16
                        implicitHeight: 16
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.weight: Font.Medium
                        text: page.signedIn(account.modelData) ? page.address(account.modelData) : "Not signed in yet"
                    }
                    // Akonadi's settings for the account: sign-in, which calendars it syncs
                    QQC2.Button {
                        text: page.signedIn(account.modelData) ? "Account…" : "Sign in…"
                        onClicked: page.run("signin " + account.modelData.id)
                    }
                    QQC2.Button {
                        text: "Remove"
                        icon.name: "mingcute-delete-2-fill"
                        onClicked: page.run("remove " + account.modelData.id)
                    }
                }

                Repeater {
                    model: page.calendarsOf(account.modelData)
                    QQC2.CheckBox {
                        required property var modelData
                        Layout.leftMargin: Kirigami.Units.gridUnit
                        text: modelData.name
                        checked: modelData.checked
                        onToggled: page.setChecked(modelData.id, checked)
                    }
                }
                QQC2.Label {
                    visible: page.signedIn(account.modelData) && page.calendarsOf(account.modelData).length === 0
                    Layout.leftMargin: Kirigami.Units.gridUnit
                    color: Kirigami.Theme.disabledTextColor
                    text: "Syncing calendars…"
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            visible: page.accounts.length > 0
        }

        QQC2.Button {
            text: "Add Google account…"
            icon.name: "mingcute-add-fill"
            onClicked: page.run("add")
        }
    }
}
