// Copied from design/qml/Caps.qml by design/build/build.py. Don't edit here.
// A caps label (design/DESIGN.md Type): group and column headers, keys, tabs, status bars.
import QtQuick

Text {
    color: Theme.textMuted
    font.family: Theme.typeFamilySans
    font.pixelSize: Theme.typeSizeLabel
    font.weight: Theme.typeWeightSemibold
    font.capitalization: Font.AllUppercase
    font.letterSpacing: Theme.typeTrackingLabel * font.pixelSize
    verticalAlignment: Text.AlignVCenter
}
