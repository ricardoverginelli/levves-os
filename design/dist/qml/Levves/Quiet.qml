// Copied from design/qml/Quiet.qml by design/build/build.py. Don't edit here.
// Secondary text that reads as a remark ("five bills left this month"): italic serif, muted.
import QtQuick

Text {
    color: Theme.textMuted
    font.family: Theme.typeFamilySerif
    font.pixelSize: Theme.typeSizeBody
    font.italic: true
    font.features: { "tnum": 1, "lnum": 1 }
    verticalAlignment: Text.AlignVCenter
}
