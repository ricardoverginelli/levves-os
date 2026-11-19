// Copied from design/qml/Num.qml by design/build/build.py. Don't edit here.
// A number that gets read: sans with tabular lining figures, so live values don't jiggle. For a
// readout's big number use Title with Theme.typeSizeReadout.
import QtQuick

Text {
    color: Theme.text
    font.family: Theme.typeFamilySans
    font.pixelSize: Theme.typeSizeNumber
    font.weight: Theme.typeWeightBody
    font.features: { "tnum": 1, "lnum": 1 }
    verticalAlignment: Text.AlignVCenter
}
