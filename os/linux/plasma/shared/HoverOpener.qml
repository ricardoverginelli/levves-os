// Opens a popup on hover: after the pointer rests on its trigger for a moment,
// or at once while another hover popup is open in the same bar (like a menu
// bar). Closes it once the pointer has left both the trigger and the popup.
// Installed with bus.js; import it from a widget's contents/ui/ as
// "../../../../../leaves".
import QtQuick

import "bus.js" as LeavesBus

QtObject {
    id: opener

    property bool enabled: true
    property bool triggerHovered: false
    property bool popupHovered: false  // counts only while open
    property bool open: false
    property var bar: null             // the bar's window

    signal openRequested()
    signal closeRequested()

    readonly property bool hovered: enabled && (triggerHovered || (open && popupHovered))

    onHoveredChanged: {
        if (hovered) {
            closeTimer.stop()
            if (!open) {
                if (LeavesBus.popupOpen(bar))
                    openRequested()
                else
                    openTimer.restart()
            }
        } else {
            openTimer.stop()
            if (open)
                closeTimer.restart()
        }
    }

    onOpenChanged: {
        if (!open)
            closeTimer.stop()
        LeavesBus.setPopupOpen(bar, opener, open, () => opener.closeRequested())
    }
    Component.onDestruction: LeavesBus.setPopupOpen(bar, opener, false)

    property Timer openTimer: Timer {
        interval: 150
        onTriggered: if (opener.hovered && !opener.open) opener.openRequested()
    }
    // Long enough to cross the gap between the bar and the popup
    property Timer closeTimer: Timer {
        interval: 400
        onTriggered: if (!opener.hovered && opener.open) opener.closeRequested()
    }
}
