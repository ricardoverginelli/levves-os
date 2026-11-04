// Now-playing controls for a thin panel: "Title · Artist  ⏮ ⏯ ⏭".
// Collapsed to zero width unless a media player is playing or paused;
// opens/closes with the DESIGN.md house curve. Click the text to raise the player.
// Steps aside while the Leaves Music dock is open, which shows the same track.
// Hovering it opens the player popup (PlayerPopup.qml), which also switches
// between media sources when there's more than one.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.workspace.dbus as DBus
import Levves

import "../../../../../leaves"

PlasmoidItem {
    id: root

    // DESIGN.md motion and spacing
    readonly property int houseCurve: Easing.OutQuint
    readonly property int openDuration: Theme.durationPopupOpen
    readonly property int closeDuration: Theme.durationPopupClose
    readonly property int hoverDuration: Theme.durationHover
    readonly property int innerGap: 3  // keys in a row, as in a title bar
    readonly property int groupGap: Theme.space8
    readonly property int trailingGap: Theme.space16  // space before the tray, like the gaps between the perf meter's groups
    readonly property int maxTextWidth: 280

    // Row 0 of the model is Plasma's multiplexer, which follows whichever
    // player is active; the players themselves come after it. Picking a
    // source pins its row; row 0 again means "follow the active one".
    // The multiplexer can stay on a player that has stopped (a browser keeps
    // its MPRIS entry after the tab goes quiet) while another one plays, so
    // unpinned, any playing player wins, then any paused one.
    readonly property alias mpris: mpris
    readonly property bool pinned: mpris.currentIndex > 0
    readonly property var player: {
        const followed = mpris.currentPlayer
        if (pinned)
            return followed
        const ranked = [followed].concat(sources)
        return ranked.find(p => hasStatus(p, Mpris.PlaybackStatus.Playing))
            || ranked.find(p => hasStatus(p, Mpris.PlaybackStatus.Paused))
            || followed
    }
    readonly property bool active: player !== null
        && (player.playbackStatus === Mpris.PlaybackStatus.Playing
            || player.playbackStatus === Mpris.PlaybackStatus.Paused)
    readonly property bool playing: active && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool shown: active && !dockOpen.registered

    // The dock owns this name only while it's open (apps/leaves-music mpris.py),
    // so a dock that quits or crashes gives the bar back too
    DBus.DBusServiceWatcher {
        id: dockOpen
        busType: DBus.BusType.Session
        watchedService: "org.leavesmusic.DockOpen"
        onRegisteredChanged: if (registered) root.expanded = false
    }

    Plasmoid.status: shown ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus
    // Hover popups have no tooltips (TODO.md Top bar)
    toolTipMainText: ""
    toolTipSubText: ""

    Mpris.Mpris2Model { id: mpris }

    function hasStatus(p, status) {
        return !!p && p.playbackStatus === status
    }

    // The players' containers, multiplexer left out
    property var sources: []
    function collectSources() {
        const list = []
        for (let i = 0; i < sourceWatch.count; i++) {
            const w = sourceWatch.objectAt(i)
            if (w && w.index > 0 && w.container)
                list.push(w.container)
        }
        sources = list
    }
    Instantiator {
        id: sourceWatch
        model: mpris
        delegate: QtObject {
            required property int index
            required property var container
            onContainerChanged: root.collectSources()
        }
        onObjectAdded: root.collectSources()
        onObjectRemoved: root.collectSources()
    }

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

    HoverOpener {
        id: hoverOpener
        enabled: root.shown
        open: root.expanded
        onOpenRequested: root.expanded = true
        onCloseRequested: root.expanded = false
    }

    preferredRepresentation: compactRepresentation
    compactRepresentation: Item {
        id: container

        readonly property real openWidth: row.implicitWidth + root.trailingGap
        property real shownWidth: root.shown ? openWidth : 0

        Layout.minimumWidth: shownWidth
        Layout.preferredWidth: shownWidth
        Layout.maximumWidth: shownWidth
        Layout.fillHeight: true
        clip: true
        opacity: root.shown ? 1 : 0

        Binding { target: hoverOpener; property: "bar"; value: container.Window.window }
        Binding { target: hoverOpener; property: "triggerHovered"; value: barHover.hovered }

        Behavior on shownWidth {
            NumberAnimation {
                duration: root.shown ? root.openDuration : root.closeDuration
                easing.type: root.houseCurve
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.shown ? root.openDuration : root.closeDuration
                easing.type: root.houseCurve
            }
        }

        HoverHandler { id: barHover }

        RowLayout {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.groupGap

            // Title · Artist, the artist as a quiet remark — click to bring the player window forward
            RowLayout {
                id: label
                spacing: Theme.space4
                readonly property string artist: root.player ? root.player.artist : ""

                Text {
                    Layout.maximumWidth: label.artist ? root.maxTextWidth * 0.6 : root.maxTextWidth
                    elide: Text.ElideRight
                    font.family: Theme.typeFamilySans
                    font.pixelSize: Theme.typeSizeBody
                    color: Theme.text
                    text: root.player ? (root.player.track || root.player.identity) : ""
                }
                Quiet {
                    visible: label.artist !== ""
                    Layout.maximumWidth: root.maxTextWidth * 0.4
                    elide: Text.ElideRight
                    text: "· " + label.artist
                }

                HoverHandler {
                    enabled: root.player && root.player.canRaise
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    enabled: root.player && root.player.canRaise
                    onTapped: root.player.Raise()
                }
            }

            RowLayout {
                spacing: root.innerGap
                ControlButton {
                    flat: true  // icons only in the bar; the popup's are full keys
                    glyph: "mingcute-skip-previous-fill"
                    enabled: root.player && root.player.canGoPrevious
                    onTriggered: root.player.Previous()
                }
                ControlButton {
                    flat: true  // icons only in the bar; the popup's are full keys
                    glyph: root.playing ? "mingcute-pause-fill" : "mingcute-play-fill"
                    enabled: root.player && (root.playing ? root.player.canPause : root.player.canPlay)
                    onTriggered: root.player.PlayPause()
                }
                ControlButton {
                    flat: true  // icons only in the bar; the popup's are full keys
                    glyph: "mingcute-skip-forward-fill"
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
