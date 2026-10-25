// The accent line under an open bar item (its popup is showing): 1px at the
// bottom of its parent, growing from left to right as the popup opens and
// fading as it closes (DESIGN.md Motion: house curve, popup timing).
// Set key to what the line marks, so it grows again when that changes
// (e.g. the tray's highlight moving to another item).
// Installed with bus.js; import it from a widget's contents/ui/ as
// "../../../../../leaves".
import QtQuick

import org.kde.kirigami as Kirigami

Rectangle {
    id: line

    property bool active: false
    property var key: null

    anchors.left: parent ? parent.left : undefined
    anchors.bottom: parent ? parent.bottom : undefined
    height: 1
    width: 0
    color: Kirigami.Theme.highlightColor
    opacity: 0

    function grow() {
        shrink.stop()
        width = 0
        opacity = 1
        growth.restart()
    }

    onActiveChanged: active ? grow() : shrink.restart()
    onKeyChanged: if (active) grow()
    Component.onCompleted: if (active) grow()

    NumberAnimation {
        id: growth
        target: line
        property: "width"
        to: line.parent ? line.parent.width : 0
        duration: 240
        easing.type: Easing.OutQuint
    }
    NumberAnimation {
        id: shrink
        target: line
        property: "opacity"
        to: 0
        duration: 170
        easing.type: Easing.OutQuint
    }
    // Follows its parent's width once grown (e.g. a reading that changes size)
    Binding {
        target: line
        property: "width"
        value: line.parent ? line.parent.width : 0
        when: line.active && !growth.running
        restoreMode: Binding.RestoreNone
    }
}
