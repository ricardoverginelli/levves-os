// One screen of the frozen desktop under slurp: shows that screen's part of the
// screenshot taken when the hotkey was pressed, so tooltips and menus stay
// visible while selecting. Created once per screen by ./freeze.
import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell

Window {
    id: win
    required property var target  // QScreen
    property url source  // set by ./freeze once the picture is taken
    required property rect clip  // this screen in the picture's coordinates
    property bool shown: false
    signal drawn()

    color: "black"
    LayerShell.Window.scope: "capture-freeze"
    LayerShell.Window.screen: target
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
        | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    Image {
        anchors.fill: parent
        source: win.source
        sourceClipRect: win.clip
        smooth: false
        cache: false
    }

    onFrameSwapped: {
        if (!shown) {
            shown = true
            drawn()
        }
    }
}
