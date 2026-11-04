// A MingCute glyph on a key (design/DESIGN.md Pieces): the popup's player controls, and flat
// (an icon with a hover tint) in the bar
import QtQuick
import org.kde.kirigami as Kirigami
import Levves

Key {
    id: button

    property alias glyph: glyphIcon.source  // a MingCute icon name (Button's own icon is FINAL)
    property int iconSize: 16
    signal triggered()

    implicitWidth: iconSize + 8
    implicitHeight: iconSize + 6
    leftPadding: 0
    rightPadding: 0
    onClicked: button.triggered()

    contentItem: Item {
        Kirigami.Icon {
            id: glyphIcon
            anchors.centerIn: parent
            width: button.iconSize
            height: button.iconSize
            color: button.enabled ? Theme.text : Theme.textFaint
            isMask: true
        }
    }
}
