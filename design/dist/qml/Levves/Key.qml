// Copied from design/qml/Key.qml by design/build/build.py. Don't edit here.
// A key (design/DESIGN.md Pieces): a flat square `raised` plane, one step lighter than what it sits
// on; pressed, held (checked) or current, it's `well-pressed`. `primary` is the one amber key in a
// view, and the view's only glow. `highlighted` is the keyboard's place in a column of keys (fog at
// opacity.selection with the fog line); `tone` tints it instead, e.g. Theme.critical while a key asks
// to be pressed again. A primary key takes `tone` too, for the one place amber gives way (the
// cover's color in a player). `flat` keys (toolbars, the top bar's window strip) show only a hover
// tint until pressed or current. Set contentItem for an icon.
import QtQuick
import QtQuick.Effects
import QtQuick.Templates as T

T.Button {
    id: key
    property bool primary: false
    property color tone: Theme.accent
    property bool current: false  // the page or screen it stands for is the one shown
    readonly property bool sunk: down || checked || current
    readonly property bool toned: !Qt.colorEqual(tone, Theme.accent)
    readonly property color face: primary && toned ? (down ? Qt.darker(tone, 1.15) : hovered ? Qt.lighter(tone, 1.08) : tone)
        : primary ? (down ? Theme.accentPressed : hovered ? Theme.accentHover : Theme.accent)
        : sunk ? Theme.wellPressed : flat ? "transparent" : !enabled ? Theme.surface : Theme.raised

    implicitWidth: Math.max(implicitBackgroundWidth, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Theme.sizeKey
    leftPadding: Theme.space16
    rightPadding: Theme.space16
    hoverEnabled: true

    contentItem: Text {
        text: key.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        font.family: Theme.typeFamilySans
        font.pixelSize: Theme.typeSizeBody
        font.weight: key.primary || key.current ? Theme.typeWeightSemibold : Theme.typeWeightBody
        color: !key.enabled ? Theme.textFaint : key.primary ? Theme.textOnAccent : Theme.text
    }
    background: Item {
        implicitWidth: Theme.sizeKey
        implicitHeight: Theme.sizeKey
        RectangularShadow {  // the primary key's glow: a lit window
            anchors.fill: parent
            visible: key.primary && key.enabled
            blur: 18
            spread: 0
            color: Qt.rgba(key.face.r, key.face.g, key.face.b, Theme.opacityKeyGlow)
        }
        Rectangle {
            id: plane
            anchors.fill: parent
            color: key.face
            Rectangle {  // the keyboard's highlight
                anchors.fill: parent
                visible: key.highlighted && !key.primary
                color: key.toned ? Qt.rgba(key.tone.r, key.tone.g, key.tone.b, Theme.opacitySelection) : Theme.selectionTint
                Rectangle { width: 2; height: parent.height; color: key.toned ? key.tone : Theme.fog }
            }
            Rectangle {  // hover tint
                anchors.fill: parent
                visible: key.hovered && !key.primary && !key.sunk && key.enabled
                color: Theme.hoverTint
            }
            Rectangle {  // a current key's fog line, like the current tab
                visible: key.current && !key.primary
                width: parent.width; height: 2
                color: Theme.fog
            }
        }
    }
}
