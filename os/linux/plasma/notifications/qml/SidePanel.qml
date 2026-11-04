// The Leaves panel: a full-height Levves window on the right edge of the bar's
// monitor, 22% of its width. Notifications (with Do not disturb) on top, the
// volume mixer and brightness at the bottom (Controls.qml). The bell opens it
// (CompactRepresentation, main.qml); Esc or a click outside closes it.
// Motion comes from the KWin effect kwin-effects/leaves-popups: a window flush
// with a monitor edge slides in from it, so this window only shows and hides.
import QtQuick
import QtQuick.Window

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.layershell as LayerShell
import org.kde.notificationmanager as NotificationManager

import ".." as Ui
import "../global" as Leaves
import Levves

PlasmaCore.Window {
    id: panel

    required property PlasmoidItem applet
    required property NotificationManager.Settings notificationSettings
    required property PlasmaCore.Action clearHistoryAction
    required property NotificationManager.Notifications historyModel

    readonly property real widthShare: 0.22
    readonly property bool open: visible

    function toggle() {
        if (open) {
            close();
        } else {
            show();
        }
    }

    function show() {
        // Sized for the bell's monitor; the compositor puts the panel on the active
        // monitor (wantsToBeOnActiveScreen), the one just clicked or typed on
        const bell = panel.applet.compactRepresentationItem;
        if (bell && bell.Screen.width > 0) {
            panel.screenWidth = bell.Screen.width;
            panel.screenHeight = bell.Screen.height;
        }
        Leaves.Globals.popupNotificationsModel.hideInhibitionSummary();
        visible = true;
        requestActivate();
        content.forceActiveFocus();
    }

    function close() {
        if (!visible) {
            return;
        }
        visible = false;
        historyModel.lastRead = undefined; // reset to now
        historyModel.collapseAllGroups();
    }

    visible: false
    title: "leaves-panel"
    // Square, like Yakuake: no frame edges from the style; the engraved edge is drawn on the
    // inner (left) side only, below
    Component.onCompleted: borders = 0  // (a literal 0 isn't accepted as Qt::Edges)
    // Layer surfaces need a real size up front; the anchors then set the height
    property int screenWidth: 2560
    property int screenHeight: 1440
    width: Math.round(screenWidth * widthShare)
    height: screenHeight
    LayerShell.Window.scope: "leaves-panel"
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorRight
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.wantsToBeOnActiveScreen: true
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
    onActiveChanged: if (!active) panel.close()

    mainItem: FocusScope {
        id: content
        width: panel.width - panel.leftPadding - panel.rightPadding
        height: panel.height - panel.topPadding - panel.bottomPadding
        focus: true

        Keys.onEscapePressed: panel.close()

        // Keeps the panel open while the bell opened it on hover (tray/patches.py)
        HoverHandler { onHoveredChanged: panel.applet.leavesPanelHovered = hovered }

        // An edge-to-edge window draws its edge on the inner side only: the black edge, then
        // the engraved light line (design/DESIGN.md Edges)
        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: Theme.edgeWidth
            color: Theme.edge
        }
        Rectangle {
            anchors { left: parent.left; leftMargin: Theme.edgeWidth; top: parent.top; bottom: parent.bottom }
            width: 1
            color: Qt.rgba(1, 1, 1, Theme.opacityEdgeLight)
        }

        Ui.FullRepresentation {
            anchors.fill: parent
            // DESIGN.md spacing: panels pad 16px (no frame padding without borders)
            anchors.margins: 16
            appletInterface: panel.applet
            notificationSettings: panel.notificationSettings
            clearHistoryAction: panel.clearHistoryAction
            historyModel: panel.historyModel
            leavesOpen: panel.visible
        }
    }
}
