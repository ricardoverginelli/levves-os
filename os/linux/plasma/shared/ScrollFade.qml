// A list's scroll hint: an alpha mask (only drawn through the effect) that
// fades rows out at an edge with more content past it. Use it as
//     layer.enabled: !atYBeginning || !atYEnd
//     layer.effect: GE.OpacityMask { maskSource: fade }
// on the list, with the ScrollFade a sibling of it (not a child, or it's
// drawn into its own mask).
// Installed with bus.js; import it from a widget's contents/ui/ as
// "../../../../../leaves".
import QtQuick

Rectangle {
    id: fade

    required property Flickable view
    property int size: 24

    visible: false
    width: view.width
    height: view.height
    readonly property real edge: size / Math.max(height, 1)
    gradient: Gradient {
        GradientStop { position: 0; color: fade.view.atYBeginning ? "black" : "transparent" }
        GradientStop { position: fade.edge; color: "black" }
        GradientStop { position: 1 - fade.edge; color: "black" }
        GradientStop { position: 1; color: fade.view.atYEnd ? "black" : "transparent" }
    }
}
