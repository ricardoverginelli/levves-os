// Copied from design/qml/Title.qml by design/build/build.py. Don't edit here.
// A window, pane or section title, or a readout's number: the display face, semibold.
import QtQuick

Text {
    color: Theme.text
    font.family: Theme.typeFamilyDisplay
    font.pixelSize: Theme.typeSizeTitle
    font.weight: 650
    font.features: { "tnum": 1, "lnum": 1 }
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
}
