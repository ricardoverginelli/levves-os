// Now-playing controls for a thin panel: "Title · Artist  ⏮ ⏯ ⏭".
// Collapsed to zero width unless a media player is playing or paused;
// opens/closes with the DESIGN.md house curve. Click the text to raise the player.
// Hovering it opens the player popup (PlayerPopup.qml), which also switches
// between media sources when there's more than one.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

import "../../../../../leaves"

PlasmoidItem {
    id: root

    // DESIGN.md motion and spacing
    readonly property int houseCurve: Easing.OutQuint
    readonly property int openDuration: 240
    readonly property int closeDuration: 170
    readonly property int hoverDuration: 150
    readonly property int innerGap: 4
    readonly property int groupGap: 8
    readonly property int leadingGap: 16  // space after the perf meter, like gaps between its groups
    readonly property int maxTextWidth: 280
    readonly property font barFont: Qt.font({ family: Kirigami.Theme.defaultFont.family, pointSize: 9, weight: Font.Medium })

    // Row 0 of the model is Plasma's multiplexer, which follows whichever
    // player is active; the players themselves come after it. Picking a
    // source pins its row; row 0 again means "follow the active one".
    readonly property alias mpris: mpris
    readonly property var player: mpris.currentPlayer
    readonly property bool pinned: mpris.currentIndex > 0
    readonly property bool active: player !== null
        && (player.playbackStatus === Mpris.PlaybackStatus.Playing
            || player.playbackStatus === Mpris.PlaybackStatus.Paused)
    readonly property bool playing: active && player.playbackStatus === Mpris.PlaybackStatus.Playing

    Plasmoid.status: active ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus
    // Hover popups have no tooltips (TODO.md Top bar)
    toolTipMainText: ""
    toolTipSubText: ""

    Mpris.Mpris2Model { id: mpris }

    function pin(row) {
        mpris.currentIndex = row
    }

    onActiveChanged: {
        if (active)
            return
        // A pinned source that stops or quits hands the bar back to the
        // active one, or the bar would hide with other players still going
        if (pinned)
            pin(0)
        else
            expanded = false
    }

    function htmlEscaped(text) {
        return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;")
    }

    HoverOpener {
        id: hoverOpener
        enabled: root.active
        open: root.expanded
        onOpenRequested: root.expanded = true
        onCloseRequested: root.expanded = false
    }

    preferredRepresentation: compactRepresentation
    compactRepresentation: Item {
        id: container

        readonly property real openWidth: row.implicitWidth + root.leadingGap
        property real shownWidth: root.active ? openWidth : 0

        Layout.minimumWidth: shownWidth
        Layout.preferredWidth: shownWidth
        Layout.maximumWidth: shownWidth
        Layout.fillHeight: true
        clip: true
        opacity: root.active ? 1 : 0

        Binding { target: hoverOpener; property: "bar"; value: container.Window.window }
        Binding { target: hoverOpener; property: "triggerHovered"; value: barHover.hovered }

        Behavior on shownWidth {
            NumberAnimation {
                duration: root.active ? root.openDuration : root.closeDuration
                easing.type: root.houseCurve
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.active ? root.openDuration : root.closeDuration
                easing.type: root.houseCurve
            }
        }

        HoverHandler { id: barHover }

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

    fullRepresentation: PlayerPopup {
        id: popup
        mpris: root.mpris
        player: root.player
        pinned: root.pinned
        playing: root.playing
        shown: root.expanded
        onPinRequested: row => root.pin(row)

        Binding { target: hoverOpener; property: "popupHovered"; value: popup.hovered }
    }
}
