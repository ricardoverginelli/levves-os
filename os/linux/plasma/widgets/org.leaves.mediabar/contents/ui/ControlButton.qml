// A MingCute glyph on a key (design/DESIGN.md Pieces): the bar's and the popup's player controls
import QtQuick
import org.kde.kirigami as Kirigami
import Levves

Key {
    id: button

    property alias icon: glyph.source
    property int iconSize: 16
    signal triggered()

    implicitWidth: iconSize + 8
    implicitHeight: iconSize + 6
    leftPadding: 0
    rightPadding: 0
    onClicked: button.triggered()

    contentItem: Item {
        Kirigami.Icon {
            id: glyph
            anchors.centerIn: parent
            width: button.iconSize
            height: button.iconSize
            color: button.enabled ? Theme.text : Theme.textFaint
            isMask: true
        }
    }
}
