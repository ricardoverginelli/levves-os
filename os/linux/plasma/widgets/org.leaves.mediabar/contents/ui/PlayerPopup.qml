// The player popup under the media bar: source switcher (only with more than
// one player), cover with title/artist/album, seekable progress and controls,
// over a blurred copy of the cover and tinted with its color.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

Item {
    id: popup

    required property var mpris
    required property var player
    required property bool pinned
    required property bool playing
    required property bool shown
    readonly property alias hovered: hover.hovered
    signal pinRequested(int row)

    // DESIGN.md spacing (content 12px from the frame) and type
    readonly property int pad: 12
    readonly property int gap: 8
    readonly property int coverSize: 64
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor

    Layout.preferredWidth: 360
    Layout.minimumWidth: 360
    Layout.maximumWidth: 360
    Layout.preferredHeight: content.implicitHeight + 2 * pad
    Layout.minimumHeight: Layout.preferredHeight
    Layout.maximumHeight: Layout.preferredHeight

    HoverHandler { id: hover }

    // MPRIS only pushes the position on seeks; ask for it while it's visible
    Timer {
        interval: 500
        repeat: true
        triggeredOnStart: true
        running: popup.shown && popup.playing
        onTriggered: popup.player && popup.player.updatePosition()
    }
    onShownChanged: if (shown && player) player.updatePosition()

    // The cover's own color for the progress, like Spotify's Android
    // notification; held light enough to read on the darkened background
    property color tint: coverColors.ready ? readable(coverColors.highlight) : Kirigami.Theme.highlightColor
    Behavior on tint {
        ColorAnimation { duration: 240; easing.type: Easing.OutQuint }
    }

    function readable(c) {
        const l = Math.min(0.78, Math.max(0.62, c.hslLightness))
        const s = Math.min(0.7, c.hslSaturation)
        return Qt.hsla(Math.max(0, c.hslHue), s, l, 1)
    }

    Kirigami.ImageColors {
        id: coverColors
        property bool ready: false
        source: cover
        onPaletteChanged: ready = cover.status === Image.Ready
    }
    Connections {
        target: cover
        function onStatusChanged() {
            if (cover.status === Image.Ready)
                coverColors.update()
            else
                coverColors.ready = false
        }
    }

    // Blurred, darkened cover behind everything, out to the frame's edge
    // (the style pads popups by 4px inside a 12px corner). Two layers, so a
    // new cover fades in over the old one once it has loaded.
    Item {
        id: backdrop
        anchors.fill: parent
        anchors.margins: -4
        readonly property string url: popup.player ? popup.player.artUrl : ""
        property int front: -1  // the layer shown, -1 for none

        function show(url) {
            const current = front === 0 ? artA : front === 1 ? artB : null
            if (url === "")
                front = -1
            else if (!current || current.url !== url)
                (current === artA ? artB : artA).url = url
        }
        onUrlChanged: show(url)
        Component.onCompleted: show(url)

        BlurredArt { id: artA; shown: backdrop.front === 0; onLoaded: backdrop.front = 0 }
        BlurredArt { id: artB; shown: backdrop.front === 1; onLoaded: backdrop.front = 1 }
    }

    function formatTime(us) {
        const total = Math.max(0, Math.floor(us / 1e6))
        const h = Math.floor(total / 3600)
        const m = Math.floor(total / 60) % 60
        const s = String(total % 60).padStart(2, "0")
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${s}` : `${m}:${s}`
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: popup.pad
        spacing: popup.pad

        // Sources: one chip per player (row 0 is the multiplexer, so it's
        // skipped). Click one to pin it, click the pinned one to follow
        // whichever player is active again. They split the width evenly.
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: sources.count > 2

            Repeater {
                id: sources
                model: popup.mpris
                delegate: SourceChip {}
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: popup.pad

            Rectangle {
                Layout.preferredWidth: popup.coverSize
                Layout.preferredHeight: popup.coverSize
                Layout.alignment: Qt.AlignTop
                radius: 8
                color: Qt.alpha(Kirigami.Theme.textColor, 0.06)

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    visible: cover.status !== Image.Ready
                    source: "mingcute-music-2-fill"
                    color: popup.mutedColor
                    isMask: true
                }

                Kirigami.ShadowedImage {
                    id: cover
                    anchors.fill: parent
                    radius: 8
                    source: popup.player ? popup.player.artUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(popup.coverSize * 2, popup.coverSize * 2)
                    asynchronous: true
                    visible: status === Image.Ready
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: popup.player ? (popup.player.track || popup.player.identity) : ""
                    font: Qt.font({ family: Kirigami.Theme.defaultFont.family, pointSize: 11, weight: Font.Medium })
                    color: Kirigami.Theme.textColor
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap

                    // Like the bar: click the title to bring the player forward
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: popup.player && popup.player.canRaise
                        onClicked: popup.player.Raise()
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: popup.player ? popup.player.artist : ""
                    font.pointSize: 10
                    color: popup.mutedColor
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: popup.player ? popup.player.album : ""
                    font.pointSize: 9
                    color: popup.mutedColor
                    elide: Text.ElideRight
                }
            }
        }

        // Progress: 4px track, 6px under the pointer; click or drag to seek
        Item {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: 12
            visible: popup.player !== null && popup.player.length > 0

            readonly property real length: popup.player ? popup.player.length : 0
            readonly property real fraction: length > 0 && popup.player
                ? Math.min(1, Math.max(0, (seek.pressed ? seek.preview : popup.player.position) / length)) : 0
            readonly property bool canSeek: popup.player !== null && popup.player.canSeek

            Rectangle {
                id: groove
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: seek.containsMouse || seek.pressed ? 6 : 4
                radius: height / 2
                color: Qt.alpha(Kirigami.Theme.textColor, 0.12)

                Behavior on height {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuint }
                }

                Rectangle {
                    width: Math.max(groove.height, groove.width * track.fraction)
                    height: parent.height
                    radius: parent.radius
                    color: popup.tint
                }
            }

            MouseArea {
                id: seek
                property real preview: 0
                anchors.fill: parent
                hoverEnabled: true
                enabled: track.canSeek
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                function at(x) { return Math.min(1, Math.max(0, x / width)) * track.length }
                onPressed: mouse => preview = at(mouse.x)
                onPositionChanged: mouse => { if (pressed) preview = at(mouse.x) }
                onReleased: mouse => {
                    popup.player.position = at(mouse.x)
                    popup.player.updatePosition()
                }
            }
        }

        // Elapsed at the left, buttons in the middle, length at the right
        Item {
            Layout.fillWidth: true
            implicitHeight: buttons.implicitHeight

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: track.visible
                text: popup.formatTime(track.fraction * track.length)
                font.pointSize: 9
                color: popup.mutedColor
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: track.visible
                text: popup.formatTime(track.length)
                font.pointSize: 9
                color: popup.mutedColor
            }

            RowLayout {
                id: buttons
                anchors.centerIn: parent
                spacing: 16

                ControlButton {
                    icon: "mingcute-skip-previous-fill"
                    iconSize: 20
                    implicitWidth: 32
                    implicitHeight: 32
                    enabled: popup.player && popup.player.canGoPrevious
                    onTriggered: popup.player.Previous()
                }
                ControlButton {
                    icon: popup.playing ? "mingcute-pause-fill" : "mingcute-play-fill"
                    iconSize: 24
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 20
                    enabled: popup.player && (popup.playing ? popup.player.canPause : popup.player.canPlay)
                    onTriggered: popup.player.PlayPause()
                }
                ControlButton {
                    icon: "mingcute-skip-forward-fill"
                    iconSize: 20
                    implicitWidth: 32
                    implicitHeight: 32
                    enabled: popup.player && popup.player.canGoNext
                    onTriggered: popup.player.Next()
                }
            }
        }
    }

    component BlurredArt: Item {
        id: art
        property string url
        property bool shown
        signal loaded()

        anchors.fill: parent
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: 240; easing.type: Easing.OutQuint }
        }

        // Rounded to the frame's corner
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: artMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
        Item {
            id: artMask
            anchors.fill: parent
            layer.enabled: true
            visible: false
            Rectangle { anchors.fill: parent; radius: 12 }
        }

        // Drawn past the edges, so the blur doesn't fade out at the corners
        Image {
            id: artImage
            anchors.fill: parent
            anchors.margins: -32
            source: art.url
            sourceSize: Qt.size(32, 32)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
            onStatusChanged: if (status === Image.Ready) art.loaded()
        }
        MultiEffect {
            anchors.fill: artImage
            source: artImage
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 32
            brightness: -0.35
            saturation: 0.1
        }

        // The glass fill over it, so text reads even on a white cover
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.75)
        }
    }

    component SourceChip: Rectangle {
        id: chip
        required property int index
        required property string identity
        required property var container

        // The bar's player: the pinned row, or the one the multiplexer follows
        readonly property bool current: popup.pinned
            ? popup.mpris.currentIndex === index
            : container !== null && popup.player !== null
              && container.instancePid === popup.player.instancePid
              && container.identity === popup.player.identity
        readonly property bool pinnedHere: popup.pinned && current

        visible: index > 0
        Layout.fillWidth: true
        Layout.preferredWidth: 1  // equal shares, whatever the names' lengths
        Layout.minimumWidth: chipRow.implicitWidth + 16
        implicitHeight: 24
        radius: 8
        color: current ? Qt.alpha(Kirigami.Theme.textColor, 0.12)
             : chipMouse.containsMouse ? Qt.alpha(Kirigami.Theme.textColor, 0.06)
             : "transparent"

        Behavior on color {
            ColorAnimation { duration: 150; easing.type: Easing.OutQuint }
        }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4

            Kirigami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 12
                visible: chip.pinnedHere
                source: "mingcute-pin-fill"
                color: Kirigami.Theme.textColor
                isMask: true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.identity
                font.pointSize: 9
                font.weight: chip.current ? Font.Medium : Font.Normal
                color: chip.current ? Kirigami.Theme.textColor : popup.mutedColor
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: popup.pinRequested(chip.pinnedHere ? 0 : chip.index)
        }
    }
}
