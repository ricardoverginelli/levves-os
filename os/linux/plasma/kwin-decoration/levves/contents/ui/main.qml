// The window decoration's root: KWin reads the borders and the padding (the shadow's room) from here.
// Everything drawn is in Frame.qml, loaded under a fresh URL each time: KWin's QML engine caches
// files by URL until logout, so a reinstalled Frame.qml shows on the next new window.
import QtQuick
import org.kde.kwin.decoration
import Levves

Decoration {
    id: root
    alpha: true  // the shadow and the 2px corners

    Loader {
        anchors.fill: parent
        Component.onCompleted: setSource(Qt.resolvedUrl("Frame.qml") + "?v=" + Date.now(), { deco: root })
    }

    Component.onCompleted: {
        // The black edge and the engraved line inside it, under a 30px title bar
        borders.setBorders(2);
        borders.setTitle(Theme.sizeTitleBar + 1);
        maximizedBorders.setBorders(0);
        maximizedBorders.setTitle(Theme.sizeTitleBar);
        extendedBorders.setAllBorders(4);  // room to grab for resizing, outside the thin edge
        // The shadow: 10px around, dropped 3px
        padding.left = 10;
        padding.right = 10;
        padding.top = 7;
        padding.bottom = 13;
    }
}
