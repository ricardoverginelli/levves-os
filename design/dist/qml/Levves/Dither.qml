// Copied from design/qml/Dither.qml by design/build/build.py. Don't edit here.
// Deprecated: Survey's dither texture. Its tiles are flat now (both colors equal); remove uses.
import QtQuick

Image {
    property string tone: "strip"

    source: Qt.resolvedUrl(`dither-${tone}.svg`)  // against this file, not the one using it
    sourceSize: Qt.size(Theme.sizeDither, Theme.sizeDither)
    fillMode: Image.Tile
    smooth: false
}
