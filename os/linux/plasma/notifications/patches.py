"""Changes the Leaves notifications make to Plasma's stock notifications QML (see build.py).

Each patch replaces an exact snippet; if the snippet is gone (Plasma changed
it), PatchError stops the build so the stock applet stays in use.
Theme.* is the Levves module (build.py adds `import Levves` where a patch uses it).

- spacing: content 12px from the popup's edges (the style's 4px plus 8), gaps
  on the 4px grid, popups 8px from the bar and from each other
- type: a serif semibold title; app name and time as caps labels in text-muted
- icons: MingCute for configure, minimize/restore, close and the thumbnail's
  menu button; app icons listed in leavesAppIcons are swapped for a MingCute
  one in text-muted (Spectacle's colored logo)
- buttons: keys (design/DESIGN.md Pieces); the first action is the primary (amber) key
- panel: the bell (click or hover) opens a full-height sheet on the right (qml/SidePanel.qml)
  instead of a tray popup: notifications as group boxes with Do not disturb, then the
  volume mixer and a brightness slider per monitor (qml/Controls.qml); the tray
  takes volume and brightness out of the bar for it
- colors: timeout bar in text-faint (the accent stays on the primary button),
  critical notifications marked in critical
"""


class PatchError(Exception):
    pass


def replace(files, name, old, new):
    text = files[name]
    if text.count(old) != 1:
        raise PatchError(f"{name}: snippet not found once: {old.strip().splitlines()[0][:60]!r}")
    files[name] = text.replace(old, new)


POPUP = "contents/ui/NotificationPopup.qml"
GLOBALS = "contents/ui/global/Globals.qml"
BASE = "contents/ui/delegates/BaseDelegate.qml"
DELEGATE_POPUP = "contents/ui/delegates/DelegatePopup.qml"
DELEGATE_HISTORY = "contents/ui/delegates/DelegateHistory.qml"
HEADER = "contents/ui/components/NotificationHeader.qml"
BUTTONS = "contents/ui/components/HeadingButtons.qml"
SUMMARY = "contents/ui/components/Summary.qml"
ACTIONS = "contents/ui/components/ActionContainer.qml"
THUMBNAIL = "contents/ui/components/ThumbnailStrip.qml"
FULL = "contents/ui/FullRepresentation.qml"
MAIN = "contents/ui/main.qml"
COMPACT = "contents/ui/CompactRepresentation.qml"
DRAGGABLE = "contents/ui/DraggableDelegate.qml"

# Extra padding inside the popup, on top of the style's 4px
PAD = 8

APP_ICON = '''
    // Leaves: MingCute stand-ins for app icons that clash with the design, by
    // a piece of the app's icon name; drawn as a mask in text-muted like the app name
    readonly property var leavesAppIcons: ({ "spectacle": "mingcute-screenshot-fill" })
    readonly property string leavesAppIcon: {
        const name = String(modelInterface.applicationIconSource).toLowerCase();
        const key = Object.keys(leavesAppIcons).find(key => name.includes(key));
        return key ? leavesAppIcons[key] : "";
    }

    Kirigami.Icon {
        id: applicationIconItem
        Layout.preferredWidth: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Kirigami.Units.iconSizes.small
        source: notificationHeading.leavesAppIcon || notificationHeading.modelInterface.applicationIconSource
        isMask: notificationHeading.leavesAppIcon !== ""
        color: Kirigami.Theme.disabledTextColor
        visible: valid
    }
'''

ACTION_BUTTON = '''            PlasmaComponents3.ToolButton {
                id: leavesActionButton
                required property int index
                required property string label
                required property string actionName
                Layout.fillWidth: true
                Layout.maximumWidth: implicitWidth
                Layout.leftMargin: index > 0 ? 8 : 0  // Leaves

                // Leaves: the first action is the primary (amber) key, the rest are plain keys
                readonly property bool leavesPrimary: index === 0
                leftPadding: 12
                rightPadding: 12
                topPadding: 6
                bottomPadding: 6
                Kirigami.Theme.inherit: false
                Kirigami.Theme.textColor: leavesPrimary ? Theme.textOnAccent : Theme.text
                // A caps label, as on every key
                font.family: Theme.typeFamilySans
                font.pixelSize: Theme.typeSizeSmall
                font.weight: Theme.typeWeightSemibold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: Theme.typeTrackingLabel * Theme.typeSizeSmall
                background: Item {  // Leaves: a key (design/DESIGN.md Pieces)
                    readonly property bool sunk: leavesActionButton.down || false
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusKey
                        visible: !parent.sunk
                        color: leavesActionButton.leavesPrimary ? Theme.accentEdge : Theme.keyDepth
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: parent.sunk ? 0 : Theme.edgeKeyDepth
                        radius: Theme.radiusKey
                        color: parent.sunk ? Theme.fieldEdge : leavesActionButton.leavesPrimary ? Theme.accentHover : Theme.keyEdge
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Theme.edgeWidth
                        anchors.bottomMargin: parent.sunk ? Theme.edgeWidth : Theme.edgeKeyDepth
                        radius: Theme.radiusKey - 1
                        color: leavesActionButton.leavesPrimary ? (leavesActionButton.down ? Theme.accentPressed : leavesActionButton.hovered ? Theme.accentHover : Theme.accent)
                            : parent.sunk ? Theme.wellPressed
                            : leavesActionButton.hovered ? Qt.tint(Theme.raised, Theme.hoverTint)
                            : Theme.raised
                    }
                }
'''

MENU_BUTTON = '''            PlasmaComponents3.Button {
                id: menuButton
                Layout.alignment: Qt.AlignTop
                Accessible.name: tooltip.text
                // Leaves: MingCute icon on a key
                icon.name: "mingcute-menu-fill"
                icon.color: Theme.text
                icon.width: 16
                icon.height: 16
                padding: 8
                background: Item {  // Leaves: a key (design/DESIGN.md Pieces)
                    readonly property bool sunk: menuButton.down || menuButton.checked
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusKey
                        visible: !parent.sunk
                        color: false ? Theme.accentEdge : Theme.keyDepth
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: parent.sunk ? 0 : Theme.edgeKeyDepth
                        radius: Theme.radiusKey
                        color: parent.sunk ? Theme.fieldEdge : false ? Theme.accentHover : Theme.keyEdge
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Theme.edgeWidth
                        anchors.bottomMargin: parent.sunk ? Theme.edgeWidth : Theme.edgeKeyDepth
                        radius: Theme.radiusKey - 1
                        color: false ? (menuButton.down ? Theme.accentPressed : menuButton.hovered ? Theme.accentHover : Theme.accent)
                            : parent.sunk ? Theme.wellPressed
                            : menuButton.hovered ? Qt.tint(Theme.raised, Theme.hoverTint)
                            : Theme.raised
                    }
                }
                checkable: true
'''


# The app name and time over a notification: a caps label (design/DESIGN.md Type)
CAPS_LABEL = '        level: 5\n        color: Kirigami.Theme.disabledTextColor  // Leaves: a caps label in text-muted\n        font.family: Theme.typeFamilySans\n        font.pixelSize: Theme.typeSizeLabel\n        font.weight: Theme.typeWeightSemibold\n        font.capitalization: Font.AllUppercase\n        font.letterSpacing: Theme.typeTrackingLabel * Theme.typeSizeLabel\n'


def apply(files):
    # ── Spacing ──────────────────────────────────────────────────────────
    # Popups 8px from the bar and screen edge, and from each other
    replace(files, GLOBALS,
            "    property int popupEdgeDistance: Kirigami.Units.gridUnit * 2\n",
            "    property int popupEdgeDistance: 8  // Leaves\n")
    replace(files, GLOBALS,
            "? Kirigami.Units.smallSpacing : Kirigami.Units.gridUnit\n",
            "? Kirigami.Units.smallSpacing : 8  // Leaves\n")

    # Content 12px from every edge; the header's buttons no longer touch the
    # top edge. The popup*Padding values include our padding, so the timeout
    # bar, critical marker and thumbnail background still reach the edges.
    replace(files, POPUP,
            "        implicitHeight: notificationItem.implicitHeight\n",
            f"        implicitHeight: notificationItem.implicitHeight + {2 * PAD}  // Leaves: top and bottom padding\n")
    replace(files, POPUP,
            """            anchors {
                fill: parent
                topMargin: notificationPopup.modelInterface.closable || notificationPopup.modelInterface.dismissable || notificationPopup.modelInterface.configurable ? -notificationPopup.topPadding : 0
            }
            leftPadding: 0
            rightPadding: 0
""",
            f"""            anchors {{
                fill: parent
                topMargin: {PAD}  // Leaves
                bottomMargin: {PAD}
            }}
            leftPadding: {PAD}
            rightPadding: {PAD}
""")
    for side in ["Left", "Top", "Right", "Bottom"]:
        replace(files, POPUP,
                f"popup{side}Padding: notificationPopup.{side.lower()}Padding\n",
                f"popup{side}Padding: notificationPopup.{side.lower()}Padding + {PAD}  // Leaves\n")
    replace(files, DELEGATE_POPUP,
            """        leftPadding: Layout.mirrored ? -delegateRoot.modelInterface.popupLeftPadding : 0
        rightPadding: Layout.mirrored ? 0 : -delegateRoot.modelInterface.popupRightPadding
""",
            """        leftPadding: 0  // Leaves: the close button stays inside the padding
        rightPadding: 0
""")

    # Gaps: 12px between text and icon, 8px under the header and above the
    # actions, 4px between title and body
    replace(files, BASE,
            "    columnSpacing: Kirigami.Units.smallSpacing\n",
            "    columnSpacing: 12  // Leaves\n")
    replace(files, DELEGATE_POPUP,
            "        Layout.topMargin: delegateRoot.hasBodyText || icon.visible ? Kirigami.Units.smallSpacing : 0\n",
            "        Layout.topMargin: delegateRoot.hasBodyText || icon.visible ? 8 : 0  // Leaves\n")
    replace(files, DELEGATE_POPUP,
            "        // Base layout intentionally has no row spacing, so add top padding here\n"
            "        Layout.topMargin: Kirigami.Units.smallSpacing\n",
            "        // Base layout intentionally has no row spacing, so add top padding here\n"
            "        Layout.topMargin: 8  // Leaves\n")
    replace(files, DELEGATE_POPUP,
            "        Layout.topMargin: summary.visible ? 0 : Kirigami.Units.smallSpacing\n",
            "        Layout.topMargin: summary.visible ? 4 : 8  // Leaves\n")
    replace(files, DELEGATE_POPUP,
            "        id: footerLoader\n        Layout.fillWidth: true\n",
            "        id: footerLoader\n        Layout.fillWidth: true\n        Layout.topMargin: visible ? 8 : 0  // Leaves\n")
    replace(files, DELEGATE_HISTORY,
            "        id: bodyLabel\n        Layout.fillWidth: true\n",
            "        id: bodyLabel\n        Layout.fillWidth: true\n        Layout.topMargin: summary.visible ? 4 : 0  // Leaves\n")
    replace(files, DELEGATE_HISTORY,
            "        id: footerLoader\n        Layout.fillWidth: true\n",
            "        id: footerLoader\n        Layout.fillWidth: true\n        Layout.topMargin: visible ? 8 : 0  // Leaves\n")
    replace(files, HEADER,
            "    spacing: Kirigami.Units.smallSpacing\n",
            "    spacing: 8  // Leaves\n")
    replace(files, ACTIONS,
            """            PlasmaComponents3.ToolButton {
                required property int index
                required property string label
                required property string actionName
                Layout.fillWidth: true
                Layout.maximumWidth: implicitWidth
                Layout.leftMargin: index > 0 ? Kirigami.Units.smallSpacing : 0
""",
            ACTION_BUTTON)

    # ── Type ─────────────────────────────────────────────────────────────
    replace(files, SUMMARY,
            """    level: 4
    // Give it a bit more visual prominence than the app name in the header
    type: Kirigami.Heading.Type.Primary
""",
            """    level: 4
    // Leaves: a serif title (design/DESIGN.md Type)
    font.family: Theme.typeFamilySerif
    font.pixelSize: Theme.typeSizeTitle + 1
    font.weight: Theme.typeWeightSemibold
""")
    replace(files, HEADER,
            "        level: 5\n        opacity: 0.9\n",
            CAPS_LABEL)
    replace(files, BUTTONS,
            "        level: 5\n        opacity: 0.9\n",
            CAPS_LABEL)

    # ── Icons ────────────────────────────────────────────────────────────
    replace(files, HEADER,
            """
    Kirigami.Icon {
        id: applicationIconItem
        Layout.preferredWidth: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Kirigami.Units.iconSizes.small
        source: notificationHeading.modelInterface.applicationIconSource
        visible: valid
    }
""",
            APP_ICON)
    replace(files, BUTTONS,
            '        icon.name: "configure"\n',
            '        icon.name: "mingcute-settings-6-fill"  // Leaves\n        icon.color: Kirigami.Theme.textColor\n')
    replace(files, BUTTONS,
            '        icon.name: headingButtons.modelInterface.dismissed ? "window-restore" : "window-minimize"\n',
            '        icon.name: headingButtons.modelInterface.dismissed ? "mingcute-restore-fill" : "mingcute-minimize-fill"  // Leaves\n'
            '        icon.color: Kirigami.Theme.textColor\n')
    replace(files, BUTTONS,
            '        icon.name: "window-close"\n',
            '        icon.name: "mingcute-close-fill"  // Leaves\n        icon.color: Kirigami.Theme.textColor\n')
    replace(files, THUMBNAIL,
            """            PlasmaComponents3.Button {
                id: menuButton
                Layout.alignment: Qt.AlignTop
                Accessible.name: tooltip.text
                icon.name: "application-menu"
                checkable: true
""",
            MENU_BUTTON)

    # The thumbnail reaches the popup's sides and bottom but not up into the text
    replace(files, THUMBNAIL,
            "            topMargin: -thumbnailArea.modelInterface.popupTopPadding\n",
            "            topMargin: 0  // Leaves\n")

    # ── Colors ───────────────────────────────────────────────────────────
    replace(files, DELEGATE_POPUP,
            "            color: Kirigami.Theme.highlightColor\n",
            "            color: Theme.textFaint  // Leaves: the accent stays on the primary key\n")
    replace(files, DELEGATE_POPUP,
            "        color: Kirigami.Theme.neutralTextColor\n",
            "        color: Kirigami.Theme.negativeTextColor  // Leaves: critical\n")

    # ── Panel ────────────────────────────────────────────────────────────
    # The bell opens the side panel (qml/SidePanel.qml) instead of a tray popup:
    # the history (this file) on top, the mixer and brightness (qml/Controls.qml) under it
    replace(files, FULL,
            'import "components" as Components\n',
            'import "components" as Components\nimport "leaves" as LeavesUi\n')
    replace(files, FULL,
            "    required property NotificationManager.Notifications historyModel\n",
            "    required property NotificationManager.Notifications historyModel\n"
            "    property bool leavesOpen: false  // Leaves: the side panel is open\n")
    replace(files, FULL,
            """    Connections {
        target: fullRepresentationRoot.appletInterface
        function onExpandedChanged() {
            if (fullRepresentationRoot.appletInterface.expanded) {""",
            """    onLeavesOpenChanged: {  // Leaves
        {
            if (fullRepresentationRoot.leavesOpen) {""")
    replace(files, FULL,
            "            model: fullRepresentationRoot.appletInterface.expanded ? fullRepresentationRoot.historyModel : null\n",
            "            model: fullRepresentationRoot.leavesOpen ? fullRepresentationRoot.historyModel : null  // Leaves\n")
    replace(files, FULL,
            "    header: PlasmaExtras.PlasmoidHeading {\n",
            """    footer: Item {  // Leaves
        implicitHeight: leavesControls.implicitHeight
        LeavesUi.Controls {
            id: leavesControls
            anchors { left: parent.left; right: parent.right; top: parent.top }
        }
    }

    header: PlasmaExtras.PlasmoidHeading {
""")
    # Header: Do not disturb on the left, clear-all (MingCute) on the right, flush with the cards
    replace(files, FULL,
            "                fill: parent\n                leftMargin: Kirigami.Units.smallSpacing\n",
            "                fill: parent\n                leftMargin: 0  // Leaves\n")
    replace(files, FULL,
            '                    icon.name: "edit-clear-history"\n',
            '                    icon.name: "mingcute-delete-2-fill"  // Leaves\n'
            '                    icon.color: Kirigami.Theme.textColor\n')
    # Notifications as group boxes: the near-black edge, etched, 12px padding, 8px apart; no
    # lines between apps (the cards already separate them)
    replace(files, FULL,
            "            topMargin: Kirigami.Units.largeSpacing\n"
            "            bottomMargin: Kirigami.Units.largeSpacing\n"
            "            spacing: Kirigami.Units.smallSpacing\n",
            "            topMargin: 12  // Leaves\n"
            "            bottomMargin: 12\n"
            "            spacing: 8\n")
    replace(files, FULL,
            "                    height: y > 0 ? Math.round(Kirigami.Units.smallSpacing * 2) : 0\n",
            "                    height: 0  // Leaves: cards, no lines\n")
    replace(files, FULL,
            "                        visible: parent.y > 0\n",
            "                        visible: false  // Leaves\n")
    replace(files, FULL,
            "            delegate: DraggableDelegate {\n                id: delegate\n                width: ListView.view.width\n",
            """            delegate: DraggableDelegate {
                id: delegate
                width: ListView.view.width
                // Leaves: a group box (design/DESIGN.md Edges): the near-black edge, etched
                leftPadding: 12
                rightPadding: 12
                topPadding: 12
                bottomPadding: 12
                background: Item {
                    Rectangle {
                        x: 1; y: 1
                        width: parent.width; height: parent.height
                        radius: Theme.radiusContainer
                        color: "transparent"
                        border.color: Theme.etchLight
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusContainer
                        color: Theme.surface
                        border.color: Theme.edge
                    }
                }
""")
    # Cards have top and bottom padding (the popups have none, so they're unchanged)
    replace(files, DRAGGABLE,
            "    implicitHeight: contentItem.implicitHeight\n",
            "    implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding  // Leaves\n")

    # The bell, keyboard activation and hover all open the side panel
    replace(files, MAIN,
            """    fullRepresentation: FullRepresentation {
        appletInterface: root
        notificationSettings: notificationSettings
        clearHistoryAction: clearHistory
        historyModel: historyModel
    }
""",
            """    // Leaves: no tray popup; the side panel holds the history (leaves/SidePanel.qml)
    fullRepresentation: Item {}
    LeavesUi.SidePanel {
        id: leavesPanel
        applet: root
        notificationSettings: notificationSettings
        clearHistoryAction: clearHistory
        historyModel: historyModel
    }
    // For the tray's hover opening (tray/patches.py), which follows the side panel, not expanded
    readonly property bool leavesPanelOpen: leavesPanel.open
    property bool leavesPanelHovered: false
    function leavesShowPanel() { leavesPanel.show(); }
    function leavesClosePanel() { leavesPanel.close(); }
""")
    replace(files, MAIN,
            """    onExpandedChanged: expanded => {
        if (expanded) {
            Notifications.Globals.popupNotificationsModel.hideInhibitionSummary();
        } else {
            historyModel.lastRead = undefined; // reset to now
            historyModel.collapseAllGroups();
        }
    }
""",
            """    // Leaves: whatever expands the applet (a shortcut, the tray) opens the side panel instead
    onExpandedChanged: expanded => {
        if (expanded) {
            root.expanded = false;
            leavesPanel.toggle();
        }
    }
""")
    replace(files, MAIN,
            'import plasma.applet.org.kde.plasma.notifications as Notifications\n',
            'import plasma.applet.org.kde.plasma.notifications as Notifications\nimport "leaves" as LeavesUi\n')
    replace(files, COMPACT,
            "    onPressed: wasExpanded = root.expanded\n",
            "    onPressed: wasExpanded = leavesPanel.open  // Leaves: the side panel\n")
    replace(files, COMPACT,
            "            root.expanded = !wasExpanded;\n",
            "            if (wasExpanded) leavesPanel.close(); else leavesPanel.show();\n")
