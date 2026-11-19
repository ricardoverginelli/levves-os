// Copied from design/qml/TitleBar.qml by design/build/build.py. Don't edit here.
// A window's title plane (design/DESIGN.md Pieces): the display title, then whatever goes on the
// right (live info, keys). It cuts its own top-right corner to match its WindowFrame: set `cut: 0`
// in a docked or maximized window, or `Theme.cutPane` in a pane.
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

Item {
    id: bar
    property alias title: label.text
    property bool active: true
    property real cut: Theme.cutWindow
    property color color: active ? Theme.titleBar : Theme.titleBarInactive
    default property alias trailing: trailingRow.data
    implicitHeight: Theme.sizeTitleBar

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: bar.color
            strokeColor: "transparent"; strokeWidth: 0
            startX: 0; startY: 0
            PathLine { x: bar.width - bar.cut; y: 0 }
            PathLine { x: bar.width; y: bar.cut }
            PathLine { x: bar.width; y: bar.height }
            PathLine { x: 0; y: bar.height }
            PathLine { x: 0; y: 0 }
        }
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space12 + 2
        anchors.rightMargin: bar.cut > 0 ? bar.cut + Theme.space8 : Theme.space8
        spacing: Theme.space8
        Title {
            id: label
            Layout.fillWidth: true
            color: bar.active ? Theme.text : Theme.textMuted
        }
        RowLayout { id: trailingRow; spacing: Theme.space4 }
    }
}
