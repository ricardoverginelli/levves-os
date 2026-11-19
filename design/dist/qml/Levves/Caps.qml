// Copied from design/qml/Caps.qml by design/build/build.py. Don't edit here.
// A label (design/DESIGN.md Type): section and column headers, the bar's readings. Sentence case,
// semibold, muted. The name is Survey's, when labels were caps; the text is shown as written.
import QtQuick

Text {
    property real size: Theme.typeSizeLabel
    property real tracking: Theme.typeTrackingLabel
    color: Theme.textMuted
    font.family: Theme.typeFamilySans
    font.pixelSize: size
    font.weight: Theme.typeWeightSemibold
    font.letterSpacing: tracking * size
    verticalAlignment: Text.AlignVCenter
}
