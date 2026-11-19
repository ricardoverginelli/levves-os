// Copied from design/qml/Field.qml by design/build/build.py. Don't edit here.
// A field's frame (design/DESIGN.md Pieces): an opening in the darkest plane, `bg-deep`, with a weak
// `field-edge` outline that turns `fog` while the field has focus. Use it as a TextField's
// background (bind `focused` to the field's activeFocus), or behind a toggle or a slot.
import QtQuick

Rectangle {
    property bool focused: false
    color: Theme.bgDeep
    border.color: !enabled ? "transparent" : focused ? Theme.fog : Theme.fieldEdge
    border.width: Theme.edgeWidth
    implicitHeight: Theme.sizeField
}
