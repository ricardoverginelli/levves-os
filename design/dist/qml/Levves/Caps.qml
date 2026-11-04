// Copied from design/qml/Caps.qml by design/build/build.py. Don't edit here.
// A caps label (design/DESIGN.md Type): group and column headers, keys, tabs, status bars.
import QtQuick

Text {
    // Set size, not font.pixelSize: the tracking follows it
    property real size: Theme.typeSizeLabel
    property real tracking: Theme.typeTrackingLabel

    color: Theme.textMuted
    font.family: Theme.typeFamilySans
    font.pixelSize: size
    font.weight: Theme.typeWeightSemibold
    font.capitalization: Font.AllUppercase
    font.letterSpacing: tracking * size
    verticalAlignment: Text.AlignVCenter
}
