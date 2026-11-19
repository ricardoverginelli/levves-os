// The window decoration's root: KWin reads the borders and the padding (the shadow's room) from here.
// Everything drawn is in Frame.qml, loaded under a fresh URL each time: KWin's QML engine caches
// files by URL until logout, so a reinstalled Frame.qml shows on the next new window.
import QtQuick
import org.kde.kwin.decoration
import Levves

Decoration {
    id: root
    alpha: true  // the shadow and the cut corner

    Loader {
        anchors.fill: parent
        Component.onCompleted: setSource(Qt.resolvedUrl("Frame.qml") + "?v=" + Date.now(), { deco: root })
    }

    Component.onCompleted: {
        // The weak 1px border around a 30px title plane
        borders.setBorders(Theme.edgeWidth);
        borders.setTitle(Theme.sizeTitleBar + Theme.edgeWidth);
        maximizedBorders.setBorders(0);
        maximizedBorders.setTitle(Theme.sizeTitleBar);
        extendedBorders.setAllBorders(5);  // room to grab for resizing, outside the thin border
        // The shadow: 10px around, dropped 3px
        padding.left = 10;
        padding.right = 10;
        padding.top = 7;
        padding.bottom = 13;
    }
}
