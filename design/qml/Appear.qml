// How a window no KWin effect reaches opens and closes (design/DESIGN.md Motion): a 0.96 scale plus a
// fade, on the popup timings and the house curve. open() and close() animate `targets`; closed()
// fires once they're gone, so hide the window there. Opening from rest starts at nothing, opening
// mid-close turns back from where it is. For a Popup's enter/exit or a ListView's add/remove, use
// AppearIn and AppearOut instead.
import QtQuick

QtObject {
    id: appear
    property list<Item> targets
    readonly property bool closing: hide.running
    property bool isOpen: false
    signal closed

    function open() {
        if (!isOpen && !hide.running)
            for (const t of targets) { t.opacity = 0; t.scale = Theme.scaleAppear }
        isOpen = true
        hide.stop()
        show.start()
    }
    function close() {
        isOpen = false
        show.stop()
        hide.start()
    }

    readonly property Animation show: ParallelAnimation {
        NumberAnimation { targets: appear.targets; property: "opacity"; to: 1; duration: Theme.durationPopupOpen; easing.type: Easing.OutQuint }
        NumberAnimation { targets: appear.targets; property: "scale"; to: 1; duration: Theme.durationPopupOpen; easing.type: Easing.OutQuint }
    }
    readonly property Animation hide: SequentialAnimation {
        ParallelAnimation {
            NumberAnimation { targets: appear.targets; property: "opacity"; to: 0; duration: Theme.durationPopupClose; easing.type: Easing.OutQuint }
            NumberAnimation { targets: appear.targets; property: "scale"; to: Theme.scaleAppear; duration: Theme.durationPopupClose; easing.type: Easing.OutQuint }
        }
        ScriptAction { script: appear.closed() }
    }
}
