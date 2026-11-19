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
import Levves
import org.kde.kwin as KWin

import "sheet.js" as Sheet

Item {
    id: root

    // Levves motion and spacing (design/DESIGN.md). Not a Plasma window, so it opens like snap
    // assist (Appear).
    readonly property int houseCurve: Easing.OutQuint
    readonly property int pad: Theme.space16
    readonly property int columnGap: Theme.space24
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
        sheet.height = Math.min(layout.implicitHeight + 2 * pad + Theme.sizeTitleBar, area.height - 64) + sheet.topPadding + sheet.bottomPadding;
        sheet.x = area.x + Math.round((area.width - sheet.width) / 2);
        sheet.y = area.y + Math.round((area.height - sheet.height) / 2);
        closing = false;
        flick.contentY = 0;
        sheet.visible = true;
        appear.open();
    }

    function close() {
        if (!sheet.visible || closing)
            return;
        closing = true;
        appear.close();
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

    // A key as drawn on a Levves key (design/DESIGN.md Pieces): a flat raised square with its
    // label; Meta is the leaf
    component Keycap: Item {
        id: cap
        required property string key
        readonly property bool meta: key === "Meta"
        implicitHeight: 24
        implicitWidth: Math.max(24, (meta ? 14 : label.implicitWidth) + 12)

        Rectangle { anchors.fill: parent; radius: Theme.radiusKey; color: Theme.raised }

        Caps {
            id: label
            visible: !cap.meta
            anchors.centerIn: parent
            text: root.keyLabel(cap.key)
            color: Theme.text
        }
        Kirigami.Icon {
            visible: cap.meta
            anchors.centerIn: parent
            width: 14
            height: 14
            source: "leaves-leaf"
            isMask: true
            color: Theme.text
        }
    }

    component Joiner: Text {
        color: Theme.textFaint
        font.family: Theme.typeFamilySans
        font.pixelSize: Theme.typeSizeSmall
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

            Appear { id: appear; targets: [content]; onClosed: { sheet.visible = false; root.closing = false } }

            // Flush with the frame's edge (the style pads its content by 4, inside a 2px edge)
            TitleBar {
                id: titleBar
                x: -2
                y: -2
                width: parent.width + 4
                title: "Cheat sheet"
                Key {
                    implicitWidth: 20
                    implicitHeight: 20
                    leftPadding: 0
                    rightPadding: 0
                    onClicked: root.close()
                    contentItem: Item {
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 12
                            height: 12
                            source: "mingcute-close-fill"
                            isMask: true
                            color: Theme.textMuted
                        }
                    }
                }
            }

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: root.pad - 4  // the style's frame gives 4
                anchors.topMargin: titleBar.height - 2 + root.pad
                contentWidth: layout.implicitWidth
                contentHeight: layout.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                RowLayout {
                    id: layout
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
                            spacing: Theme.space16
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

    // A section: title, then a grid of keys and descriptions. Built with
    // explicit row/column so keys and descriptions line up across rows.
    component SectionView: GroupBox {
        id: sectionView
        required property var modelData
        required property Item column
        readonly property bool commands: modelData.kind === "commands"
        Layout.fillWidth: true
        title: modelData.title

        GridLayout {
            columns: 2
            rowSpacing: Theme.space8
            columnSpacing: Theme.space12

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
                    // Commands are code: JetBrains Mono
                    Text {
                        id: command
                        visible: sectionView.commands
                        anchors.verticalCenter: parent.verticalCenter
                        text: keysCell.modelData[0]
                        color: Theme.text
                        font.family: Theme.typeFamilyMono
                        font.pixelSize: Theme.typeSizeSmall
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
                    color: Theme.textSoft
                    font.family: Theme.typeFamilySans
                    font.pixelSize: Theme.typeSizeBody
                }
            }
        }
    }
}
