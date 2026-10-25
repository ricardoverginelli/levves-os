"""Changes the Leaves tray makes to Plasma's stock tray QML (see build.py).

Each patch replaces an exact snippet; if the snippet is gone (Plasma changed
it), PatchError stops the build so the stock tray stays in use.

Where items go (edit the lists in LEAVES below):
- removed: never drawn, but still loaded (Meta+V clipboard, the network popup
  that the perf meter's Wi-Fi reading opens, placed below the reading, which
  then shows it as open instead of the tray); also
  Media Player, which the Leaves media bar replaces
- chevron: always in the hidden-items popup
- Bluetooth: shown only while a device is connected, otherwise in the chevron
- pinned: volume, then notifications, always shown at the right end; the chevron is at the left end
- icons: MingCute for the chevron and for items listed in leavesIcon()
- hover: items in leavesHoverOpen, the network popup (perf meter) and the
  clock (a stock applet in the same bar) open on hover (shared/HoverOpener.qml),
  without tooltips, which would cover the popup
"""


class PatchError(Exception):
    pass


def replace(files, name, old, new):
    text = files[name]
    if text.count(old) != 1:
        raise PatchError(f"{name}: snippet not found once: {old.strip().splitlines()[0][:60]!r}")
    files[name] = text.replace(old, new)


MAIN = "contents/ui/main.qml"
LOADER = "contents/ui/ItemLoader.qml"
PLASMOID_ITEM = "contents/ui/PlasmoidItem.qml"
EXPANDER = "contents/ui/ExpanderArrow.qml"
HIGHLIGHT = "contents/ui/CurrentItemHighLight.qml"

ICON_OVERLAY = '''
    // Leaves: opens on hover (root.leavesHoverOpen)
    HoverHandler { id: leavesHover }
    HoverOpener {
        enabled: plasmoidContainer.inVisibleLayout && root.leavesMatches(root.leavesHoverOpen, plasmoidContainer.itemId)
        triggerHovered: leavesHover.hovered
        popupHovered: root.leavesPopupHovered
        open: plasmoidContainer.applet?.expanded ?? false
        bar: root.Window.window
        onOpenRequested: plasmoidContainer.applet.expanded = true
        onCloseRequested: plasmoidContainer.applet.expanded = false
    }

    // Leaves: a MingCute icon drawn over the applet's own, which stays (invisible) for clicks
    readonly property string leavesIconName: root.leavesIcon(itemId, applet?.plasmoid?.icon ?? "")
    Kirigami.Icon {
        parent: plasmoidContainer.iconContainer
        anchors.fill: parent
        visible: plasmoidContainer.leavesIconName !== ""
        source: plasmoidContainer.leavesIconName
        isMask: true
        color: Kirigami.Theme.textColor
    }
    Binding {
        target: plasmoidContainer.applet
        property: "opacity"
        value: 0
        when: plasmoidContainer.leavesIconName !== ""
    }
'''

LEAVES = '''
    // ── Leaves (linux/plasma/tray/patches.py) ────────────────────────────
    // Ids match by prefix (some apps add a counter, e.g. NordPass_status_icon_1)
    // (Media Player: the Leaves media bar covers it)
    readonly property var leavesRemoved: ["Yakuake", "NordPass", "org.kde.plasma.clipboard", "org.kde.plasma.networkmanagement",
                                          "org.kde.plasma.mediacontroller"]
    readonly property var leavesInChevron: ["steam"]
    // Notifications: the Leaves ones (../notifications/) or the stock ones
    readonly property var leavesPinned: ["org.kde.plasma.volume", "org.kde.plasma.notifications", "org.leaves.notifications"]
    readonly property var leavesHoverOpen: ["org.kde.plasma.volume", "org.kde.plasma.notifications", "org.leaves.notifications",
                                            "org.kde.plasma.brightness"]

    // Pointer over the tray's popup (set in the popup, see apply())
    property bool leavesPopupHovered: false

    // The clock opens on hover too. It's a stock applet, so the tray finds it
    // among the items of its bar and watches it from here.
    property Item leavesClock: null
    property HoverHandler leavesClockPopupHover: null
    // The panel's tooltip area around the clock
    readonly property Item leavesClockToolTip: {
        for (let item = leavesClock?.compactRepresentationItem; item; item = item.parent)
            if (item.objectName === "org.kde.desktop-CompactApplet" && item.plasmoidItem === leavesClock)
                return item
        return null
    }
    Binding {
        target: root.leavesClockToolTip
        property: "active"
        value: false
        when: root.leavesClockToolTip !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
    function leavesFindApplet(item, pluginName) {
        if (!item)
            return null
        if (item.plasmoid?.pluginName === pluginName && item.fullRepresentation !== undefined)
            return item
        for (const child of item.children) {
            const found = leavesFindApplet(child, pluginName)
            if (found)
                return found
        }
        return null
    }
    function leavesWatchClockPopup() {
        const popup = leavesClock?.fullRepresentationItem
        if (popup && leavesClockPopupHover?.parent !== popup)
            leavesClockPopupHover = Qt.createQmlObject("import QtQuick; HoverHandler {}", popup)
    }
    Timer {  // the clock may load after the tray
        interval: 1000
        repeat: true
        running: !root.leavesClock
        onTriggered: {
            root.leavesClock = root.leavesFindApplet(root.Window.window?.contentItem ?? null,
                                                     "org.kde.plasma.digitalclock")
            root.leavesWatchClockPopup()
        }
    }
    Connections {
        target: root.leavesClock
        function onFullRepresentationItemChanged() { root.leavesWatchClockPopup() }
    }
    HoverOpener {
        triggerHovered: root.leavesClock?.compactRepresentationItem?.containsMouse ?? false
        popupHovered: root.leavesClockPopupHover?.hovered ?? false
        open: root.leavesClock?.expanded ?? false
        bar: root.Window.window
        onOpenRequested: root.leavesClock.expanded = true
        onCloseRequested: root.leavesClock.expanded = false
    }

    function leavesMatches(list, itemId) {
        return list.some(prefix => itemId.startsWith(prefix))
    }

    // The status an item gets in the Leaves tray; HiddenStatus means not drawn
    function leavesStatus(itemId, status, applet) {
        if (leavesMatches(leavesRemoved, itemId))
            return PlasmaCore.Types.HiddenStatus
        if (leavesMatches(leavesPinned, itemId))
            return PlasmaCore.Types.ActiveStatus  // always shown, even with nothing to report
        if (status !== PlasmaCore.Types.ActiveStatus)
            return status
        if (leavesMatches(leavesInChevron, itemId))
            return PlasmaCore.Types.PassiveStatus
        if (itemId === "org.kde.plasma.bluetooth")
            return applet?.plasmoid?.icon === "network-bluetooth-activated-symbolic"
                ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus
        return status
    }

    // Role numbers by name: a proxy filtering on a role name exposes its number
    // as filterRole (QML can't look roles up directly)
    KItemModels.KSortFilterProxyModel {
        id: leavesItemIdRole
        filterRoleName: "itemId"
        Component.onCompleted: sourceModel = Plasmoid.systemTrayModel
    }
    KItemModels.KSortFilterProxyModel {
        id: leavesAppletRole
        filterRoleName: "applet"
        Component.onCompleted: sourceModel = Plasmoid.systemTrayModel
    }
    KItemModels.KSortFilterProxyModel {
        id: leavesStatusRole
        filterRoleName: "effectiveStatus"
        Component.onCompleted: sourceModel = Plasmoid.systemTrayModel
    }

    // "visible", "pinned", "chevron", "removed" or "" (stock-hidden)
    function leavesPlace(model, row, parent) {
        const index = model.index(row, 0, parent)
        const itemId = model.data(index, leavesItemIdRole.filterRole) ?? ""
        const status = leavesStatus(itemId, model.data(index, leavesStatusRole.filterRole),
                                    model.data(index, leavesAppletRole.filterRole) ?? null)
        if (status === PlasmaCore.Types.ActiveStatus)
            return leavesMatches(leavesPinned, itemId) ? "pinned" : "visible"
        if (status === PlasmaCore.Types.PassiveStatus)
            return "chevron"
        return leavesMatches(leavesRemoved, itemId) ? "removed" : ""
    }

    // MingCute icons the tray draws over an item's own (DESIGN.md Icons); "" keeps the item's.
    // Brightness follows its widget's icon, so Night Light still shows as a moon.
    function leavesIcon(itemId, iconName) {
        if (itemId === "org.kde.plasma.brightness")
            return /night|redshift/.test(iconName) ? "mingcute-moon-fill" : "mingcute-sun-fill"
        return ""
    }

    // Re-sorts items between the bar and the chevron. Rebuilding the rows closes
    // any open popup, so it only runs when Bluetooth actually changes place.
    property bool leavesBluetoothConnected: false
    function leavesBluetoothChanged(icon) {
        const connected = icon === "network-bluetooth-activated-symbolic"
        if (connected === leavesBluetoothConnected)
            return
        leavesBluetoothConnected = connected
        activeModel.invalidateFilter()
        hiddenModel.invalidateFilter()
    }

    // The item the popup opens under instead of the tray (e.g. the perf meter's
    // Wi-Fi reading); cleared once another item's popup takes over
    property Item leavesAnchor: null
    // The tray looks open (chevron, highlight) only for popups under itself
    readonly property bool leavesOpenHere: systemTrayState.expanded && !leavesAnchor
    Binding {
        target: root.leavesAnchor
        property: "leavesPopupOpen"
        value: systemTrayState.expanded
        when: root.leavesAnchor?.leavesPopupOpen !== undefined
        restoreMode: Binding.RestoreValue
    }
    Binding {
        target: root.leavesAnchor
        property: "leavesPopupHovered"
        value: root.leavesPopupHovered
        when: root.leavesAnchor?.leavesPopupHovered !== undefined
        restoreMode: Binding.RestoreValue
    }
    Connections {
        target: systemTrayState
        function onActiveAppletChanged() {
            if (systemTrayState.activeApplet?.plasmoid?.pluginName !== "org.kde.plasma.networkmanagement")
                root.leavesAnchor = null
        }
    }

    // Opens/closes a removed item's popup (e.g. the perf meter's Wi-Fi reading → network),
    // under anchor if given
    function leavesSetExpanded(itemId, expanded, anchor) {
        for (let i = 0; i < removedModel.rowCount(); i++) {
            const index = removedModel.index(i, 0)
            if (removedModel.data(index, leavesItemIdRole.filterRole) === itemId) {
                const applet = removedModel.data(index, leavesAppletRole.filterRole)
                if (applet && applet.expanded !== expanded) {
                    if (expanded)
                        root.leavesAnchor = anchor ?? null
                    applet.expanded = expanded
                }
                return
            }
        }
    }

    KItemModels.KSortFilterProxyModel {
        id: pinnedModel
        filterRowCallback: (sourceRow, sourceParent) => root.leavesPlace(sourceModel, sourceRow, sourceParent) === "pinned"
        // Volume, then notifications: org.kde.plasma.volume sorts after the stock
        // notifications' id but before the Leaves ones' (org.leaves.notifications)
        sortRoleName: "itemId"
        sortOrder: Plasmoid.configuration.extraItems.includes("org.leaves.notifications")
            ? Qt.AscendingOrder : Qt.DescendingOrder
        Component.onCompleted: sourceModel = Plasmoid.systemTrayModel
    }

    KItemModels.KSortFilterProxyModel {
        id: removedModel
        filterRowCallback: (sourceRow, sourceParent) => root.leavesPlace(sourceModel, sourceRow, sourceParent) === "removed"
        Component.onCompleted: sourceModel = Plasmoid.systemTrayModel
    }

    // Bluetooth's place follows its icon (connected or not), which isn't a model role
    Instantiator {
        id: leavesIconWatcher
        active: false
        delegate: Connections {
            required property var model
            target: model.itemId === "org.kde.plasma.bluetooth" ? (model.applet?.plasmoid ?? null) : null
            ignoreUnknownSignals: true
            function onIconChanged() { root.leavesBluetoothChanged(target.icon) }
        }
    }

    property var leavesUnregister: null
    Component.onDestruction: if (leavesUnregister) leavesUnregister()

    Instantiator {
        id: pinnedInstantiator
        active: false
        model: pinnedModel
        delegate: Connections {
            required property QtObject applet
            required property int row
            target: applet
            function onExpandedChanged(expanded: bool) {
                if (expanded) {
                    systemTrayState.setActiveApplet(applet, row)
                }
            }
        }
    }

    // Removed items can still open their popup (shortcuts, the bus)
    Instantiator {
        id: removedInstantiator
        active: false
        model: removedModel
        delegate: Connections {
            required property QtObject applet
            required property int row
            target: applet
            function onExpandedChanged(expanded: bool) {
                if (expanded) {
                    systemTrayState.setActiveApplet(applet, row)
                }
            }
        }
    }
'''

PINNED_GRID = '''
            // Leaves: volume, then notifications, always at the right end
            GridView {
                id: pinnedGrid

                Layout.row: root.vertical ? 2 : 0
                Layout.column: root.vertical ? 0 : 2
                Layout.alignment: Qt.AlignCenter

                interactive: false
                flow: tasksGrid.flow
                cellWidth: tasksGrid.cellWidth
                cellHeight: tasksGrid.cellHeight
                implicitHeight: root.vertical ? cellHeight * count : root.height
                implicitWidth: !root.vertical ? cellWidth * count : root.width

                model: pinnedModel
                delegate: ItemLoader {
                    width: pinnedGrid.cellWidth
                    height: pinnedGrid.cellHeight
                }
            }
'''


def apply(files):
    # 16px icons (DESIGN.md) instead of Kirigami's 22px smallMedium
    replace(files, MAIN,
            "readonly property int smallIconSize: Kirigami.Units.iconSizes.smallMedium",
            "readonly property int smallIconSize: Kirigami.Units.iconSizes.small  // Leaves: 16px")

    # The message bus other Leaves widgets use to reach the tray
    replace(files, MAIN,
            "import org.kde.plasma.plasmoid\n",
            'import org.kde.plasma.plasmoid\n\nimport "../../../../../leaves/bus.js" as LeavesBus\n')

    # HoverOpener (shared/), installed next to bus.js
    for name in [MAIN, PLASMOID_ITEM]:
        replace(files, name,
                "import org.kde.plasma.plasmoid\n",
                'import org.kde.plasma.plasmoid\n\nimport "../../../../../leaves"\n')

    # Tells hover popups when the pointer is over the tray's popup
    replace(files, MAIN,
            "                id: expandedRepresentation\n",
            "                id: expandedRepresentation\n\n"
            "                HoverHandler { onHoveredChanged: root.leavesPopupHovered = hovered }  // Leaves\n")

    # Placement rules, the extra models and their popup tracking
    replace(files, MAIN,
            "    readonly property alias hiddenModel: hiddenModel\n",
            "    readonly property alias hiddenModel: hiddenModel\n" + LEAVES)

    replace(files, MAIN,
            """        id: activeModel
        filterRoleName: "effectiveStatus"
        filterRowCallback: (sourceRow, sourceParent) => {
            let value = sourceModel.data(sourceModel.index(sourceRow, 0, sourceParent), filterRole);
            return value === PlasmaCore.Types.ActiveStatus;
        }""",
            """        id: activeModel
        filterRoleName: "effectiveStatus"
        filterRowCallback: (sourceRow, sourceParent) => root.leavesPlace(sourceModel, sourceRow, sourceParent) === "visible\"""")

    replace(files, MAIN,
            """        id: hiddenModel
        filterRoleName: "effectiveStatus"
        filterRowCallback: (sourceRow, sourceParent) => {
            let value = sourceModel.data(sourceModel.index(sourceRow, 0, sourceParent), filterRole);
            return value === PlasmaCore.Types.PassiveStatus
        }""",
            """        id: hiddenModel
        filterRoleName: "effectiveStatus"
        filterRowCallback: (sourceRow, sourceParent) => root.leavesPlace(sourceModel, sourceRow, sourceParent) === "chevron\"""")

    replace(files, MAIN,
            "        activeInstantiator.active = true;\n        hiddenInstantiator.active = true;\n",
            """        activeInstantiator.active = true;
        hiddenInstantiator.active = true;
        pinnedInstantiator.active = true;
        removedInstantiator.active = true;
        leavesIconWatcher.model = Plasmoid.systemTrayModel;
        leavesIconWatcher.active = true;
        root.leavesUnregister = LeavesBus.register("network", () => root.Window.window,
                                                   arg => root.leavesSetExpanded("org.kde.plasma.networkmanagement", arg.expanded, arg.anchor));
        Qt.callLater(() => {  // the role numbers above are known only now
            activeModel.invalidateFilter();
            hiddenModel.invalidateFilter();
            pinnedModel.invalidateFilter();
            removedModel.invalidateFilter();
        });
""")

    # Popups open under leavesAnchor when one is set
    replace(files, MAIN,
            "            visualParent: root\n",
            "            visualParent: root.leavesAnchor ?? root  // Leaves\n")

    # Chevron at the left end, then the regular items, then the pinned ones
    replace(files, MAIN,
            "                Layout.column: 0                                        // to prevent overlapping\n",
            "                Layout.column: root.vertical ? 0 : 1  // Leaves: after the chevron\n")
    replace(files, MAIN,
            "                Layout.column: root.vertical ? 0 : 1                     // to prevent overlapping\n",
            "                Layout.column: 0  // Leaves: chevron at the left end\n")
    replace(files, MAIN,
            "                visible: root.hiddenLayout.itemCount > 0\n            }\n",
            "                visible: root.hiddenLayout.itemCount > 0\n            }\n" + PINNED_GRID)

    # MingCute chevron (top panel: down when closed, up when open); the
    # MingCute SVGs are masks, so the arrows are tinted with the text color
    replace(files, EXPANDER,
            """        source: {
            if (Plasmoid.location === PlasmaCore.Types.TopEdge) {
                return "arrow-down-symbolic";""",
            """        isMask: true
        color: Kirigami.Theme.textColor
        source: {
            if (Plasmoid.location === PlasmaCore.Types.TopEdge) {
                return "mingcute-down-fill";""")
    replace(files, EXPANDER,
            """        source: {
            if (Plasmoid.location === PlasmaCore.Types.TopEdge) {
                return "arrow-up-symbolic";""",
            """        isMask: true
        color: Kirigami.Theme.textColor
        source: {
            if (Plasmoid.location === PlasmaCore.Types.TopEdge) {
                return "mingcute-up-fill";""")

    # No open look on the tray while the popup is under another item (leavesAnchor)
    for old in ["rotation: systemTrayState.expanded ? 180 : 0", "opacity: systemTrayState.expanded ? 0 : 1",
                "rotation: systemTrayState.expanded ? 0 : -180", "opacity: systemTrayState.expanded ? 1 : 0"]:
        replace(files, EXPANDER, old, old.replace("systemTrayState.expanded", "root.leavesOpenHere"))
    replace(files, HIGHLIGHT,
            "    function updateHighlightedItem() {\n        if (systemTrayState.expanded) {",
            "    function updateHighlightedItem() {\n        if (root.leavesOpenHere) {")
    replace(files, HIGHLIGHT,
            "        currentItemHighLight.opacity = systemTrayState.expanded ? 1 : 0",
            "        currentItemHighLight.opacity = root.leavesOpenHere ? 1 : 0")

    # No tooltips on items that open on hover
    replace(files, PLASMOID_ITEM,
            "    active: inVisibleLayout || (systemTrayState.activeApplet !== applet && (text != mainText || subText.length > 0))\n",
            "    active: !root.leavesMatches(root.leavesHoverOpen, itemId)  // Leaves\n"
            "        && (inVisibleLayout || (systemTrayState.activeApplet !== applet && (text != mainText || subText.length > 0)))\n")

    # Icon overrides for applets (see leavesIcon)
    replace(files, PLASMOID_ITEM,
            "AbstractItem {\n    id: plasmoidContainer\n",
            "AbstractItem {\n    id: plasmoidContainer\n" + ICON_OVERLAY)

    # Items see the Leaves status, so forced-chevron items lay out as hidden ones
    replace(files, LOADER,
            "            effectiveStatus: Qt.binding(() => effectiveStatus),\n",
            "            effectiveStatus: Qt.binding(() => root.leavesStatus(model.itemId ?? \"\", effectiveStatus, model.applet ?? null)),\n")
