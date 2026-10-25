// A MingCute glyph on a rounded hover/press tint (DESIGN.md: 4px small-control radius, hover tint)
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: button

    property alias icon: glyph.source
    property int iconSize: 16
    signal triggered()

    implicitWidth: iconSize + 4
    implicitHeight: iconSize + 4
    radius: 4
    color: mouse.pressed ? Qt.alpha(Kirigami.Theme.textColor, 0.16)
         : mouse.containsMouse ? Qt.alpha(Kirigami.Theme.textColor, 0.10)
         : "transparent"
    opacity: enabled ? 1 : 0.4

    Behavior on color {
        ColorAnimation {
            duration: 150  // DESIGN.md hover
            easing.type: Easing.OutQuint
        }
    }

    Kirigami.Icon {
        id: glyph
        anchors.centerIn: parent
        width: button.iconSize
        height: button.iconSize
        color: Kirigami.Theme.textColor
        isMask: true
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: button.enabled
        onClicked: button.triggered()
    }
}
