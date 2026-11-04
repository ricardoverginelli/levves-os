// The player popup under the media bar, a Levves window (design/DESIGN.md): source keys (only with
// more than one player), the cover in a well with title/artist/album, a sunk screen showing the
// player's audio (Visualizer.qml), a meter to seek, and the controls. The cover's color stands in
// for the accent: the screen's curve and the meter's fill.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris
import Levves

Item {
    id: popup

    required property var mpris
    required property var player
    required property bool pinned
    required property bool playing
    required property bool shown
    readonly property alias hovered: hover.hovered
    signal pinRequested(int row)

    // Levves spacing (content 12px from the frame) and type
    readonly property int pad: Theme.space12
    readonly property int gap: Theme.space8
    readonly property int coverSize: 64
    readonly property color mutedColor: Theme.textMuted

    Layout.preferredWidth: 360
    Layout.minimumWidth: 360
    Layout.maximumWidth: 360
    Layout.preferredHeight: content.implicitHeight + 2 * pad
    Layout.minimumHeight: Layout.preferredHeight
    Layout.maximumHeight: Layout.preferredHeight

    HoverHandler { id: hover }

    // The players for the source chips, playing ones first, then by model
    // row. Row 0 is Plasma's multiplexer (it follows the active player), so
    // it's left out whenever there are players after it.
    property var sources: []
    function sortSources() {
        const list = []
        for (let i = 0; i < watchers.count; i++) {
            const w = watchers.objectAt(i)
            if (!w || !w.container || (watchers.count > 1 && w.index === 0))
                continue
            list.push({ row: w.index, identity: w.identity, container: w.container,
                        playing: w.status === Mpris.PlaybackStatus.Playing })
        }
        list.sort((a, b) => (b.playing - a.playing) || (a.row - b.row))
        sources = list
    }
    Instantiator {
        id: watchers
        model: popup.mpris
        delegate: QtObject {
            required property int index
            required property string identity
            required property var container
            readonly property int status: container ? container.playbackStatus : -1
            onStatusChanged: Qt.callLater(popup.sortSources)
        }
        onObjectAdded: Qt.callLater(popup.sortSources)
        onObjectRemoved: Qt.callLater(popup.sortSources)
    }

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
    property color tint: coverColors.ready ? readable(coverColors.highlight) : Theme.accent
    Behavior on tint {
        ColorAnimation { duration: Theme.durationPopupOpen; easing.type: Easing.OutQuint }
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

        // Sources: one key per player, playing ones first. Click one to pin
        // it, click the pinned one to follow whichever player is active again.
        // They split the width evenly; the bar's player is held down.
        RowLayout {
            Layout.fillWidth: true
            spacing: 3
            visible: popup.sources.length > 1

            Repeater {
                model: popup.sources
                delegate: SourceKey {}
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: popup.pad

            Well {
                Layout.preferredWidth: popup.coverSize + 2
                Layout.preferredHeight: popup.coverSize + 2
                Layout.alignment: Qt.AlignTop

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    visible: cover.status !== Image.Ready
                    source: "mingcute-music-2-fill"
                    color: Theme.textFaint
                    isMask: true
                }

                Image {
                    id: cover
                    anchors.fill: parent
                    anchors.margins: 1
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

                Title {
                    Layout.fillWidth: true
                    text: popup.player ? (popup.player.track || popup.player.identity) : ""
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap

                    // Like the bar: click the title to bring the player forward
                    HoverHandler {
                        enabled: popup.player && popup.player.canRaise
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        enabled: popup.player && popup.player.canRaise
                        onTapped: popup.player.Raise()
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: popup.player ? popup.player.artist : ""
                    font.family: Theme.typeFamilySans
                    font.pixelSize: Theme.typeSizeBody
                    color: Theme.textSoft
                    elide: Text.ElideRight
                }
                Quiet {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: popup.player ? popup.player.album : ""
                    font.pixelSize: Theme.typeSizeSmall + 1
                    elide: Text.ElideRight
                }
            }
        }

        // The player's audio on a sunk screen, in the cover's tint
        Well {
            Layout.fillWidth: true
            Layout.preferredHeight: 44

            Visualizer {
                anchors.fill: parent
                anchors.margins: 1
                app: popup.player ? popup.player.identity : ""
                running: popup.shown && popup.playing
                tint: popup.tint
                strength: 2.5
            }
        }

        // Progress: a meter in the cover's tint; click or drag to seek
        Meter {
            id: track
            Layout.fillWidth: true
            visible: popup.player !== null && popup.player.length > 0
            fill: popup.tint

            readonly property real length: popup.player ? popup.player.length : 0
            readonly property real fraction: length > 0 && popup.player
                ? Math.min(1, Math.max(0, (seek.pressed ? seek.preview : popup.player.position) / length)) : 0
            readonly property bool canSeek: popup.player !== null && popup.player.canSeek
            value: fraction

            MouseArea {
                id: seek
                property real preview: 0
                anchors.fill: parent
                anchors.topMargin: -4
                anchors.bottomMargin: -4
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

        // Elapsed at the left, keys in the middle, length at the right
        Item {
            Layout.fillWidth: true
            implicitHeight: buttons.implicitHeight

            Num {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: track.visible
                text: popup.formatTime(track.fraction * track.length)
                font.pixelSize: Theme.typeSizeBar
                color: Theme.textMuted
            }
            Num {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: track.visible
                text: popup.formatTime(track.length)
                font.pixelSize: Theme.typeSizeBar
                color: Theme.textMuted
            }

            RowLayout {
                id: buttons
                anchors.centerIn: parent
                spacing: 3

                ControlButton {
                    glyph: "mingcute-skip-previous-fill"
                    iconSize: 16
                    implicitWidth: 40
                    implicitHeight: Theme.sizeKey
                    enabled: popup.player && popup.player.canGoPrevious
                    onTriggered: popup.player.Previous()
                }
                ControlButton {
                    glyph: popup.playing ? "mingcute-pause-fill" : "mingcute-play-fill"
                    iconSize: 16
                    implicitWidth: 56
                    implicitHeight: Theme.sizeKey
                    enabled: popup.player && (popup.playing ? popup.player.canPause : popup.player.canPlay)
                    onTriggered: popup.player.PlayPause()
                }
                ControlButton {
                    glyph: "mingcute-skip-forward-fill"
                    iconSize: 16
                    implicitWidth: 40
                    implicitHeight: Theme.sizeKey
                    enabled: popup.player && popup.player.canGoNext
                    onTriggered: popup.player.Next()
                }
            }
        }
    }

    component SourceKey: Key {
        id: chip
        required property var modelData
        readonly property int index: modelData.row
        readonly property string identity: modelData.identity
        readonly property var container: modelData.container

        // The bar's player: the pinned row, or the one the multiplexer follows
        readonly property bool isCurrent: popup.pinned
            ? popup.mpris.currentIndex === index
            : container !== null && popup.player !== null
              && container.instancePid === popup.player.instancePid
              && container.identity === popup.player.identity
        readonly property bool pinnedHere: popup.pinned && isCurrent

        Layout.fillWidth: true
        Layout.preferredWidth: 1  // equal shares, whatever the names' lengths
        Layout.minimumWidth: chipRow.implicitWidth + 16
        implicitHeight: 24
        focusPolicy: Qt.NoFocus
        current: isCurrent
        onClicked: popup.pinRequested(chip.pinnedHere ? 0 : chip.index)

        contentItem: Item {
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
                    color: Theme.text
                    isMask: true
                }
                Caps {
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.identity
                    color: chip.isCurrent ? Theme.text : Theme.textMuted
                }
            }
        }
    }
}
