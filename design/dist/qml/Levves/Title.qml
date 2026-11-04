// Copied from design/qml/Title.qml by design/build/build.py. Don't edit here.
// A window or section title: serif semibold.
import QtQuick

Text {
    color: Theme.text
    font.family: Theme.typeFamilySerif
    font.pixelSize: Theme.typeSizeTitle
    font.weight: Theme.typeWeightSemibold
    font.features: { "tnum": 1, "lnum": 1 }
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
}
