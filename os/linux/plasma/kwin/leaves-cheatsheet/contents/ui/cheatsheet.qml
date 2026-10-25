// KWin script: the Leaves cheat sheet. Meta+F12 shows the hotkeys and commands
// of this setup (sheet.json, written here as sheet.js by build.py) in a glass
// window centered on the active monitor; Meta+F12 again, Esc, the × or a click
// on another window closes it.
//
//   ┌────────────────────── Cheat sheet ─────────────────── × ┐
//   │ Shell            Windows          Capture      Keyboard │
//   │ [⌘] Launcher     [⌘]+[←] Tile…    [Print] …    …        │
//   │ …                …                …            Commands │
//   └─────────────────────────────────────────────────────────┘
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin

import "sheet.js" as Sheet

Item {
    id: root

    // DESIGN.md motion and spacing. Not a Plasma window, so it opens like snap
    // assist: a 0.96 scale plus a fade, on popup timing.
    readonly property int houseCurve: Easing.OutQuint
    readonly property int openDuration: 240
    readonly property int closeDuration: 170
    readonly property int pad: 16
    readonly property int columnGap: 32
    readonly property var colors: Sheet.palette
    property bool closing: false

    // Sections grouped into columns: a section with "column" starts a new one
    readonly property var columns: {
        const result = [];
        for (const section of Sheet.sections) {
            if (section.column !== undefined || result.length === 0)
                result.push([]);
            result[result.length - 1].push(section);
        }
        return result;
    }

    KWin.ShortcutHandler {
        name: "Leaves Cheat Sheet"
        text: "Leaves: show the cheat sheet"
        sequence: "Meta+F12"
        onActivated: sheet.visible && !root.closing ? root.close() : root.open()
    }

    // KWin keeps keyboard focus on the app window and never sends keys to a
    // script's window, so Esc is a global shortcut that exists only while open
    Loader {
        active: sheet.visible && !root.closing
        sourceComponent: KWin.ShortcutHandler {
            name: "Leaves Cheat Sheet Close"
            text: "Leaves: close the cheat sheet (only while it's open)"
            sequence: "Esc"
            onActivated: root.close()
        }
    }

    // Clicking another window counts as closing it
    Connections {
        target: KWin.Workspace
        function onWindowActivated(w) {
            if (sheet.visible && w)
                root.close();
        }
    }

    function open() {
        const area = KWin.Workspace.clientArea(KWin.Workspace.MaximizeArea, KWin.Workspace.activeScreen,
                                               KWin.Workspace.currentDesktop);
        sheet.width = Math.min(layout.implicitWidth + 2 * pad, area.width - 64) + sheet.leftPadding + sheet.rightPadding;
        sheet.height = Math.min(layout.implicitHeight + 2 * pad, area.height - 64) + sheet.topPadding + sheet.bottomPadding;
        sheet.x = area.x + Math.round((area.width - sheet.width) / 2);
        sheet.y = area.y + Math.round((area.height - sheet.height) / 2);
        closeAnim.stop();
        closing = false;
        flick.contentY = 0;
        sheet.visible = true;
        openAnim.restart();
    }

    function close() {
        if (!sheet.visible || closing)
            return;
        closing = true;
        openAnim.stop();
        closeAnim.restart();
    }

    // Shown keys: arrows as arrows, Meta as the Leaves leaf
    function keyLabel(key) {
        return ({ Left: "←", Right: "→", Up: "↑", Down: "↓", PgUp: "PgUp", PgDown: "PgDn",
                  Backspace: "⌫", Print: "PrtSc" })[key] ?? key;
    }

    // "Meta+Shift+Left / Meta+PgUp" -> [["Meta","Shift","Left"], ["Meta","PgUp"]]
    function combos(keys) {
        // "Meta++" would split wrong, so zoom keys are written "Meta+=" / "Meta+-"
        return keys.split(" / ").map(combo => combo === "+" ? ["+"] : combo.split("+"));
    }

    // ── Pieces ────────────────────────────────────────────────────────────

    // A key: raised, 1px border, 4px corners (DESIGN.md small control), mono label
    component Keycap: Rectangle {
        id: cap
        required property string key
        readonly property bool meta: key === "Meta"
        implicitHeight: 24
        implicitWidth: Math.max(24, (meta ? 14 : label.implicitWidth) + 12)
        radius: 4
        color: root.colors["raised"]
        border.width: 1
        border.color: root.colors["border"]

        Text {
            id: label
            visible: !cap.meta
            anchors.centerIn: parent
            text: root.keyLabel(cap.key)
            color: root.colors["text"]
            font.family: "JetBrains Mono"
            font.pointSize: 9
        }
        Kirigami.Icon {
            visible: cap.meta
            anchors.centerIn: parent
            width: 14
            height: 14
            source: "leaves-leaf"
            isMask: true
            color: root.colors["text"]
        }
    }

    component Joiner: Text {
        color: root.colors["text-faint"]
        font.pointSize: 9
        Layout.alignment: Qt.AlignVCenter
    }

    // One row's keys: combos joined by "+", alternatives by "/"
    component Keys: RowLayout {
        id: keysRow
        required property string keys
        spacing: 4
        Repeater {
            model: root.combos(keysRow.keys)
            delegate: RowLayout {
                id: comboItem
                required property var modelData
                required property int index
                spacing: 4
                Joiner { visible: comboItem.index > 0; text: "/"; Layout.leftMargin: 4; Layout.rightMargin: 4 }
                Repeater {
                    model: comboItem.modelData
                    delegate: RowLayout {
                        id: keyItem
                        required property string modelData
                        required property int index
                        spacing: 4
                        Joiner { visible: keyItem.index > 0; text: "+" }
                        Keycap { key: keyItem.modelData }
                    }
                }
            }
        }
    }

    // ── Window ────────────────────────────────────────────────────────────

    PlasmaCore.Window {
        id: sheet
        visible: false
        flags: Qt.X11BypassWindowManagerHint | Qt.FramelessWindowHint

        mainItem: Item {
            id: content
            width: sheet.width - sheet.leftPadding - sheet.rightPadding
            height: sheet.height - sheet.topPadding - sheet.bottomPadding

            ParallelAnimation {
                id: openAnim
                NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: root.openDuration; easing.type: root.houseCurve }
                NumberAnimation { target: content; property: "scale"; from: 0.96; to: 1; duration: root.openDuration; easing.type: root.houseCurve }
            }
            SequentialAnimation {
                id: closeAnim
                ParallelAnimation {
                    NumberAnimation { target: content; property: "opacity"; to: 0; duration: root.closeDuration; easing.type: root.houseCurve }
                    NumberAnimation { target: content; property: "scale"; to: 0.96; duration: root.closeDuration; easing.type: root.houseCurve }
                }
                ScriptAction { script: { sheet.visible = false; root.closing = false } }
            }

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: root.pad - 4  // the style's frame gives 4
                contentWidth: layout.implicitWidth
                contentHeight: layout.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ColumnLayout {
                    id: layout
                    spacing: 24  // DESIGN.md: between sections

                    // Title, centered, with the close button at the end
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 28
                        Text {
                            anchors.centerIn: parent
                            text: "Cheat sheet"
                            color: root.colors["text"]
                            font.pointSize: 11
                            font.weight: Font.Medium
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28
                            radius: 4
                            color: closeMouse.containsMouse ? Qt.alpha(root.colors["text"], 0.06) : "transparent"
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                source: "mingcute-close-fill"
                                isMask: true
                                color: root.colors["text"]
                            }
                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.close()
                            }
                        }
                    }

                    RowLayout {
                        spacing: root.columnGap
                        Repeater {
                            model: root.columns
                            delegate: ColumnLayout {
                                id: sheetColumn
                                required property var modelData
                                // The widest keys in the column: every section's
                                // descriptions start at the same x
                                property real keyWidth: 0
                                Layout.alignment: Qt.AlignTop
                                spacing: 24
                                Repeater {
                                    model: sheetColumn.modelData
                                    delegate: SectionView { column: sheetColumn }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // A section: title, then a grid of keys and descriptions. Built with
    // explicit row/column so keys and descriptions line up across rows.
    component SectionView: ColumnLayout {
        id: sectionView
        required property var modelData
        required property Item column
        readonly property bool commands: modelData.kind === "commands"
        spacing: 12  // DESIGN.md: a section's title to its content

        Text {
            text: sectionView.modelData.title
            color: root.colors["text"]
            font.pointSize: 11
            font.weight: Font.Medium
        }

        GridLayout {
            columns: 2
            rowSpacing: 8
            columnSpacing: 12

            Repeater {
                model: sectionView.modelData.rows
                delegate: Item {
                    id: keysCell
                    required property var modelData
                    required property int index
                    Layout.row: index
                    Layout.column: 0
                    Layout.preferredWidth: sectionView.column.keyWidth
                    implicitWidth: sectionView.commands ? command.implicitWidth : keys.implicitWidth
                    implicitHeight: 24
                    onImplicitWidthChanged: sectionView.column.keyWidth = Math.max(sectionView.column.keyWidth, implicitWidth)
                    Keys {
                        id: keys
                        visible: !sectionView.commands
                        keys: keysCell.modelData[0]
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        id: command
                        visible: sectionView.commands
                        anchors.verticalCenter: parent.verticalCenter
                        text: keysCell.modelData[0]
                        color: root.colors["text"]
                        font.family: "JetBrains Mono"
                        font.pointSize: 9
                    }
                }
            }
            Repeater {
                model: sectionView.modelData.rows
                delegate: Text {
                    required property var modelData
                    required property int index
                    Layout.row: index
                    Layout.column: 1
                    Layout.alignment: Qt.AlignVCenter
                    text: modelData[1]
                    color: root.colors["text-muted"]
                    font.pointSize: 10
                }
            }
        }
    }
}
