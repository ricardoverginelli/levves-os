// The cover behind a player (DESIGN.md, the cover exception): blurred, held down near `surface` so
// text keeps its contrast, and screened by a 1px dither so it reads as printed rather than as
// glass. Two layers, so a new cover fades in over the old one once it has loaded. Used by the
// Leaves Music dock and the top bar's media popup.
//
// `cut` leaves out the top-right corner, for a backdrop inside a frame cut there: every pixel
// whose center lies within `cut` of the corner (along both edges together) stays clear.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: backdrop
    property string url
    property real cut: 0
    property int front: -1
    clip: true

    function show(next) {
        if (next === "") { front = -1; return }
        const current = front === 0 ? a : front === 1 ? b : null
        if (current && current.source.toString() === next) return
        const back = current === a ? b : a
        // Already loaded there (the same cover back after a gap): no new status would come
        if (back.source.toString() === next && back.status === Image.Ready) front = back === a ? 0 : 1
        else back.source = next
    }
    onUrlChanged: show(url)
    Component.onCompleted: show(url)

    // The cut, as a mask; aliased, so each pixel is either in or out, like the frame's staircase
    layer.enabled: cut > 0
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: outline
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0
    }
    Item {
        id: outline
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Shape {
            anchors.fill: parent
            ShapePath {
                strokeWidth: -1
                fillColor: "white"
                startX: 0; startY: 0
                PathLine { x: outline.width - backdrop.cut; y: 0 }
                PathLine { x: outline.width; y: backdrop.cut }
                PathLine { x: outline.width; y: outline.height }
                PathLine { x: 0; y: outline.height }
            }
        }
    }

    component Layer: Image {
        property bool shown
        // Drawn past the edges, so the blur doesn't fade out there
        x: -80
        y: -80
        width: parent.width + 160
        height: parent.height + 160
        sourceSize: Qt.size(128, 128)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationPopupOpen; easing.type: Easing.OutQuint } }
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1
            blurMax: 64
            saturation: 0.15
        }
    }
    Layer { id: a; shown: backdrop.front === 0; onStatusChanged: if (status === Image.Ready) backdrop.front = 0 }
    Layer { id: b; shown: backdrop.front === 1; onStatusChanged: if (status === Image.Ready) backdrop.front = 1 }

    // Most of `surface` over it: the cover shows as a cast of color, not a picture. Only while a
    // cover shows, so without one the frame's own fill stays as it is.
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.surface, 0.72)
        opacity: backdrop.front >= 0 ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationPopupOpen; easing.type: Easing.OutQuint } }
    }
    Image {  // the dither, as a screen: every other pixel a little darker
        anchors.fill: parent
        source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='2' height='2'>"
              + "<rect x='1' width='1' height='1' fill-opacity='0.22'/>"
              + "<rect y='1' width='1' height='1' fill-opacity='0.22'/></svg>"
        sourceSize: Qt.size(Theme.sizeDither, Theme.sizeDither)
        fillMode: Image.Tile
        smooth: false
    }
}
