// A soft silhouette of the music rising from the popup's bottom edge: one
// smooth filled curve through the spectrum in the cover's tint, faint enough
// that the blurred cover still shows through, from edge to edge. Levels come
// from ../code/visualizer.py, started here on demand; it records only the
// given player's own stream and exits once nothing asks it for levels.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import org.kde.plasma.plasma5support as P5Support

Item {
    id: visualizer

    property string app        // the player's MPRIS identity
    property bool running      // popup open and playing
    property color tint        // the cover's color
    readonly property int bands: 32
    readonly property int steps: 8  // curve samples between two bands

    // The helper's readings arrive 30 times a second; what's drawn glides
    // toward them every frame. On pause the targets drop to zero, so the curve
    // settles into the bottom edge, and it rises out of it again on play.
    property var levels: new Array(bands).fill(0)   // targets
    property var drawn: new Array(bands).fill(0)
    readonly property real riseTime: 0.07   // seconds to cover ~63% of the way
    readonly property real fallTime: 0.14
    readonly property real settleTime: 0.25 // pausing, or the popup closing
    property var points: []
    property real presence: 0  // fades the top line out as the curve flattens

    readonly property string helper: decodeURIComponent(
        Qt.resolvedUrl("../code/visualizer.py").toString().replace(/^file:\/\//, ""))
    property real lastLaunch: 0

    onRunningChanged: {
        if (!running)
            levels = new Array(bands).fill(0)
        frames.settled = false
    }
    onWidthChanged: points = outline(drawn)
    onHeightChanged: points = outline(drawn)

    FrameAnimation {
        id: frames
        property bool settled: true
        running: visualizer.visible && (visualizer.running || !settled)
        onTriggered: {
            const next = []
            let moving = false
            for (let i = 0; i < visualizer.bands; i++) {
                const from = visualizer.drawn[i], to = visualizer.levels[i] ?? 0
                const tau = !visualizer.running ? visualizer.settleTime
                          : to > from ? visualizer.riseTime : visualizer.fallTime
                const v = from + (to - from) * (1 - Math.exp(-frameTime / tau))
                next.push(v)
                moving = moving || Math.abs(to - v) > 0.002
            }
            visualizer.drawn = next
            visualizer.presence = Math.min(1, Math.max(...next) * 4)
            visualizer.points = visualizer.outline(next)
            settled = !moving
        }
    }

    // Closed outline: along the bottom, then up through each band's level.
    // A light 3-band blend takes the edge off single-band spikes but keeps
    // the peaks steep, a power curve deepens the valleys, and Catmull-Rom
    // curves join the bands.
    function outline(raw) {
        const n = raw.length
        const at = i => raw[Math.min(n - 1, Math.max(0, i))]
        const ys = []
        for (let i = 0; i < n; i++)
            ys.push(0.85 * Math.pow((at(i - 1) + 4 * at(i) + at(i + 1)) / 6, 1.4))

        const w = width, h = height, last = ys.length - 1
        const out = [Qt.point(w, h), Qt.point(0, h)]
        for (let i = 0; i < last; i++) {
            const p0 = ys[Math.max(0, i - 1)], p1 = ys[i], p2 = ys[i + 1], p3 = ys[Math.min(last, i + 2)]
            for (let s = 0; s < steps; s++) {
                const t = s / steps, t2 = t * t, t3 = t2 * t
                const y = 0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                                 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
                out.push(Qt.point((i + t) / last * w, h - Math.max(0, y) * h))
            }
        }
        out.push(Qt.point(w, h - ys[last] * h))
        return out
    }

    Timer {
        interval: 33
        repeat: true
        running: visualizer.running && visualizer.app !== ""
        onTriggered: visualizer.poll()
    }

    function poll() {
        const request = new XMLHttpRequest()
        request.onreadystatechange = () => {
            if (request.readyState !== XMLHttpRequest.DONE || !running)
                return
            if (request.status === 200)
                levels = JSON.parse(request.responseText).levels
            else
                launch()
        }
        request.open("GET", "http://127.0.0.1:48731/levels?app=" + encodeURIComponent(app))
        request.send()
    }

    // Not running yet (or it exited while idle): start it, at most every 2s
    function launch() {
        const now = Date.now()
        if (now - lastLaunch < 2000)
            return
        lastLaunch = now
        executable.connectSource("python3 -I '" + helper.replace(/'/g, "'\\''") + "'")
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        onNewData: source => disconnectSource(source)
    }

    // Edge to edge, so it takes the frame's rounded bottom corners
    layer.enabled: true
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: corners
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
    Item {
        id: corners
        anchors.fill: parent
        layer.enabled: true
        visible: false
        Rectangle {
            anchors.fill: parent
            bottomLeftRadius: 7
            bottomRightRadius: 7
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                y1: 0
                y2: visualizer.height
                GradientStop { position: 0; color: Qt.alpha(visualizer.tint, 0.03) }
                GradientStop { position: 1; color: Qt.alpha(visualizer.tint, 0.10) }
            }
            PathPolyline { path: visualizer.points }
        }
        // A faint line along the top, so the curve keeps an edge
        ShapePath {
            strokeWidth: 1.5
            strokeColor: Qt.alpha(visualizer.tint, 0.22 * visualizer.presence)
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline { path: visualizer.points.slice(2) }
        }
    }
}
