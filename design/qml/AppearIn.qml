// Appear's open as a Transition, for a Popup's `enter` or a ListView's `add`: `enter: AppearIn {}`.
import QtQuick

Transition {
    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationPopupOpen; easing.type: Easing.OutQuint }
    NumberAnimation { property: "scale"; from: Theme.scaleAppear; to: 1; duration: Theme.durationPopupOpen; easing.type: Easing.OutQuint }
}
