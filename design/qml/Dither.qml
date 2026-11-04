// The dither texture: a 1px checkerboard (design/DESIGN.md Pieces). "strip" for group headers,
// status bars and disabled keys, "desktop" behind everything, "well" in meter tracks and empty slots.
import QtQuick

Image {
    property string tone: "strip"

    source: Qt.resolvedUrl(`dither-${tone}.svg`)  // against this file, not the one using it
    sourceSize: Qt.size(Theme.sizeDither, Theme.sizeDither)
    fillMode: Image.Tile
    smooth: false
}
