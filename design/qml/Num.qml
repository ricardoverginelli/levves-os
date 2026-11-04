// A number that gets read: serif, tabular lining figures, so live values don't jiggle.
import QtQuick

Text {
    color: Theme.text
    font.family: Theme.typeFamilySerif
    font.pixelSize: Theme.typeSizeNumber
    font.features: { "tnum": 1, "lnum": 1 }
    verticalAlignment: Text.AlignVCenter
}
