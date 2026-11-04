// Copied from design/qml/Key.qml by design/build/build.py. Don't edit here.
// A key (design/DESIGN.md Pieces): `raised`, a lighter outline and a 2px bottom edge; pressed, held
// (checked) or current, it sinks into `well-pressed`. `primary` is the one amber key in a view.
// `highlighted` is the keyboard's place in a column of keys (amber at opacity.selection, the one
// accent in the view); `tone` tints it instead, e.g. Theme.critical while a key asks to be pressed again.
// `flat` keys (toolbars, the top bar's window strip) show only a hover tint until pressed or current.
// The label is a caps label by default; set contentItem for an icon.
import QtQuick
import QtQuick.Templates as T

T.Button {
    id: key
    property bool primary: false
    property color tone: Theme.accent
    property bool current: false  // the page or screen it stands for is the one shown
    readonly property bool sunk: down || checked || current

    implicitWidth: Math.max(implicitBackgroundWidth, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Theme.sizeKey
    leftPadding: Theme.space12
    rightPadding: Theme.space12
    topPadding: sunk ? 1 : 0
    bottomPadding: sunk || flat ? 0 : Theme.edgeKeyDepth - 1
    hoverEnabled: true

    contentItem: Caps {
        text: key.text
        horizontalAlignment: Text.AlignHCenter
        size: Theme.typeSizeSmall
        color: !key.enabled ? Theme.textFaint : key.primary ? Theme.textOnAccent : Theme.text
    }

    background: Item {
        implicitWidth: Theme.sizeKey
        implicitHeight: Theme.sizeKey

        Rectangle {  // the bottom edge, showing under the face
            anchors.fill: parent
            radius: Theme.radiusKey
            visible: !key.sunk && key.enabled && !key.flat
            color: key.primary ? Theme.accentEdge : Theme.keyDepth
        }
        Rectangle {  // the outline
            visible: !key.flat || key.sunk
            anchors.fill: parent
            anchors.bottomMargin: key.sunk || !key.enabled ? 0 : Theme.edgeKeyDepth
            radius: Theme.radiusKey
            color: key.sunk ? Theme.fieldEdge : !key.enabled ? Theme.raised
                : key.primary ? Theme.accentHover : Theme.keyEdge
        }
        Rectangle {  // the face
            id: face
            anchors.fill: parent
            anchors.margins: Theme.edgeWidth
            anchors.bottomMargin: key.sunk || !key.enabled || key.flat ? Theme.edgeWidth : Theme.edgeKeyDepth
            radius: Theme.radiusKey - 1
            clip: true
            color: key.primary ? (key.down ? Theme.accentPressed : key.hovered ? Theme.accentHover : Theme.accent)
                : key.sunk ? Theme.wellPressed : key.flat ? "transparent" : !key.enabled ? Theme.surface : Theme.raised

            Dither { anchors.fill: parent; visible: !key.enabled && !key.flat }
            Rectangle {  // the keyboard's highlight
                anchors.fill: parent
                visible: key.highlighted && !key.primary
                color: Qt.rgba(key.tone.r, key.tone.g, key.tone.b, Theme.opacitySelection)
            }
            Rectangle {  // hover tint
                anchors.fill: parent
                visible: key.hovered && !key.primary && !key.sunk && key.enabled
                color: Theme.hoverTint
            }
            Rectangle {  // the inner shadow of a sunk key
                width: parent.width; height: 3
                visible: key.sunk
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(0, 0, 0, key.primary ? 0.3 : 0.5) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
        }
    }
}
