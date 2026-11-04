// Appear's close as a Transition, for a Popup's `exit` or a ListView's `remove`: `exit: AppearOut {}`.
import QtQuick

Transition {
    NumberAnimation { property: "opacity"; to: 0; duration: Theme.durationPopupClose; easing.type: Easing.OutQuint }
    NumberAnimation { property: "scale"; to: Theme.scaleAppear; duration: Theme.durationPopupClose; easing.type: Easing.OutQuint }
}
