// Now-playing controls for a thin panel: "Title · Artist  ⏮ ⏯ ⏭".
// Collapsed to zero width unless a media player is playing or paused;
// opens/closes with the DESIGN.md house curve. Click the text to raise the player.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

PlasmoidItem {
    id: root

    // DESIGN.md motion and spacing
    readonly property var houseCurve: [0.2, 0.8, 0.2, 1, 1, 1]
    readonly property int openDuration: 200
    readonly property int closeDuration: 140
    readonly property int hoverDuration: 120
    readonly property int innerGap: 4
    readonly property int groupGap: 8
    readonly property int leadingGap: 16  // space after the perf meter, like gaps between its groups
    readonly property int maxTextWidth: 280
    readonly property font barFont: Qt.font({ family: Kirigami.Theme.defaultFont.family, pointSize: 9, weight: Font.Medium })

    readonly property var player: mpris.currentPlayer
    readonly property bool active: player !== null
        && (player.playbackStatus === Mpris.PlaybackStatus.Playing
            || player.playbackStatus === Mpris.PlaybackStatus.Paused)
    readonly property bool playing: active && player.playbackStatus === Mpris.PlaybackStatus.Playing

    Plasmoid.status: active ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus
    toolTipMainText: active ? player.track : ""
    toolTipSubText: active ? [player.artist, player.identity].filter(Boolean).join(" — ") : ""

    Mpris.Mpris2Model { id: mpris }

    function htmlEscaped(text) {
        return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;")
    }

    preferredRepresentation: fullRepresentation
    fullRepresentation: Item {
        id: container

        readonly property real openWidth: row.implicitWidth + root.leadingGap
        property real shownWidth: root.active ? openWidth : 0

        Layout.minimumWidth: shownWidth
        Layout.preferredWidth: shownWidth
        Layout.maximumWidth: shownWidth
        Layout.fillHeight: true
        clip: true
        opacity: root.active ? 1 : 0

        Behavior on shownWidth {
            NumberAnimation {
                duration: root.active ? root.openDuration : root.closeDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.houseCurve
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.active ? root.openDuration : root.closeDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.houseCurve
            }
        }

        RowLayout {
            id: row
            x: root.leadingGap
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.groupGap

            // Title · Artist — click to bring the player window forward
            Text {
                id: label
                Layout.maximumWidth: root.maxTextWidth
                elide: Text.ElideRight
                font: root.barFont
                textFormat: Text.StyledText
                color: Kirigami.Theme.textColor
                text: {
                    if (!root.player) return ""
                    const title = root.player.track || root.player.identity
                    const artist = root.player.artist
                    const muted = Kirigami.Theme.disabledTextColor
                    return root.htmlEscaped(title) + (artist ? ` <font color="${muted}">· ${root.htmlEscaped(artist)}</font>` : "")
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.player && root.player.canRaise
                    onClicked: root.player.Raise()
                }
            }

            RowLayout {
                spacing: root.innerGap
                ControlButton {
                    icon: "mingcute-skip-previous-fill"
                    enabled: root.player && root.player.canGoPrevious
                    onTriggered: root.player.Previous()
                }
                ControlButton {
                    icon: root.playing ? "mingcute-pause-fill" : "mingcute-play-fill"
                    enabled: root.player && (root.playing ? root.player.canPause : root.player.canPlay)
                    onTriggered: root.player.PlayPause()
                }
                ControlButton {
                    icon: "mingcute-skip-forward-fill"
                    enabled: root.player && root.player.canGoNext
                    onTriggered: root.player.Next()
                }
            }
        }
    }

    component ControlButton: Rectangle {
        property alias icon: glyph.source
        signal triggered()

        implicitWidth: 20
        implicitHeight: 20
        radius: 8
        color: mouse.pressed ? Qt.alpha(Kirigami.Theme.textColor, 0.16)
             : mouse.containsMouse ? Qt.alpha(Kirigami.Theme.textColor, 0.10)
             : "transparent"
        opacity: enabled ? 1 : 0.4

        Behavior on color {
            ColorAnimation {
                duration: root.hoverDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.houseCurve
            }
        }

        Kirigami.Icon {
            id: glyph
            anchors.centerIn: parent
            width: 16
            height: 16
            color: Kirigami.Theme.textColor
            isMask: true
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: parent.enabled
            onClicked: parent.triggered()
        }
    }
}
