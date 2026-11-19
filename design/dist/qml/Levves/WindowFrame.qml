// Copied from design/qml/WindowFrame.qml by design/build/build.py. Don't edit here.
// A window's or pane's body (design/DESIGN.md Surfaces): a flat `surface` fill, the weak `edge`
// border and the top-right cut. For windows drawn in QML (KWin scripts, apps, the window
// decoration); Plasma's popups get the same frame from the Plasma style. Put a TitleBar and the
// content inside it: the border stays drawn over them, and a TitleBar cuts its own corner to match.
//
// `pane` is a shell pane (popups, OSDs, menus): the smaller cut and the lamp light from the
// top-right, frosted (translucent `surface` at opacity.pane; the blur itself comes from KWin). A pane
// inside an app window, where nothing can blur (a QtQuick Popup or Menu), sets `frosted: false`
// and stays solid.
// `docked` is for a window flush against a monitor edge (a side panel, a dock): no cut, and only the
// side that faces the screen ("left" for a window docked on the right) gets the border.
// `bare` draws no border and no cut (a maximized window), only the fill.
import QtQuick
import QtQuick.Shapes

Item {
    id: frame
    property string docked: ""
    property bool bare: false
    property bool pane: false
    property bool cut: true
    property bool frosted: pane
    property color color: frosted
        ? Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, Theme.opacityPane)
        : Theme.surface
    readonly property bool free: docked === "" && !bare
    readonly property real cutSize: free && cut ? (pane ? Theme.cutPane : Theme.cutWindow) : 0

    // The outline as a closed path, half a pixel in so the 1px stroke lands on whole pixels
    component Outline: ShapePath {
        readonly property real r: frame.width - 0.5
        readonly property real b: frame.height - 0.5
        startX: 0.5; startY: 0.5
        PathLine { x: r - frame.cutSize; y: 0.5 }
        PathLine { x: r; y: 0.5 + frame.cutSize }
        PathLine { x: r; y: b }
        PathLine { x: 0.5; y: b }
        PathLine { x: 0.5; y: 0.5 }
    }

    Shape {  // the fill, and a pane's lamp light pooled at the top-right
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        Outline { fillColor: frame.color; strokeColor: "transparent"; strokeWidth: 0 }
        Outline {
            strokeColor: "transparent"; strokeWidth: 0
            fillGradient: frame.pane ? lamp : null
            fillColor: "transparent"
        }
        RadialGradient {
            id: lamp
            centerX: frame.width; centerY: 0
            focalX: centerX; focalY: centerY
            centerRadius: Math.max(frame.width, frame.height) * 0.9
            focalRadius: 0
            GradientStop { position: 0; color: Qt.rgba(Theme.fog.r, Theme.fog.g, Theme.fog.b, Theme.opacityLamp) }
            GradientStop { position: 0.45; color: Qt.rgba(Theme.fog.r, Theme.fog.g, Theme.fog.b, Theme.opacityLamp * 0.3) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    Shape {  // a free frame's border, over the content
        z: 1
        visible: frame.free
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        Outline { fillColor: "transparent"; strokeColor: Theme.edge; strokeWidth: Theme.edgeWidth }
    }

    Rectangle {  // a docked frame's border, on the side that faces the screen
        z: 1
        visible: frame.docked !== "" && !frame.bare
        readonly property bool across: frame.docked === "top" || frame.docked === "bottom"
        color: Theme.edge
        width: across ? frame.width : Theme.edgeWidth
        height: across ? Theme.edgeWidth : frame.height
        x: frame.docked === "right" ? frame.width - width : 0
        y: frame.docked === "bottom" ? frame.height - height : 0
    }
}
