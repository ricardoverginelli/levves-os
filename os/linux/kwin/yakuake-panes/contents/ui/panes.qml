// KWin script: Shift+Left/Right in Yakuake move between the split terminals of
// a tab, and past the first/last one on to the previous/next tab.
//
// Yakuake can't focus a given terminal over D-Bus, only step through a tab's
// terminals in the order they were made (its previous/next-terminal actions,
// which install.sh puts on Shift+Left/Right). So Yakuake moves within the tab,
// and this script takes the key only while the focused terminal is the first
// (Shift+Left) or last (Shift+Right) one, and switches tabs then (wrapping
// around like Yakuake's own tab keys). Yakuake doesn't say when its focus
// moves, so the script polls it while Yakuake is the active window; the keys
// are global shortcuts that exist only then, so other apps keep Shift+arrows.
// Install: bash install.sh in os/linux/kwin
import QtQuick
import org.kde.kwin as KWin

Item {
    id: root

    readonly property bool focused: KWin.Workspace.activeWindow !== null
        && KWin.Workspace.activeWindow.resourceClass == "org.kde.yakuake"
    property bool atFirst: false
    property bool atLast: false

    // ── Yakuake over D-Bus ──────────────────────────────────────────────────

    component YakuakeCall: KWin.DBusCall {
        service: "org.kde.yakuake"
        path: "/yakuake/sessions"
        dbusInterface: "org.kde.yakuake"
    }

    // activeTerminalId → its session → that session's terminals
    YakuakeCall {
        id: activeTerminal
        method: "activeTerminalId"
        onFinished: returnValue => {
            sessionOf.terminal = returnValue[0];
            sessionOf.arguments = [returnValue[0]];
            sessionOf.call();
        }
    }
    YakuakeCall {
        id: sessionOf
        property int terminal: -1
        method: "sessionIdForTerminalId"
        onFinished: returnValue => {
            terminalsOf.arguments = [returnValue[0]];
            terminalsOf.call();
        }
    }
    YakuakeCall {
        id: terminalsOf
        method: "terminalIdsForSessionId"
        onFinished: returnValue => {
            const ids = String(returnValue[0]).split(",").map(Number).sort((a, b) => a - b);
            root.atFirst = ids[0] == sessionOf.terminal;
            root.atLast = ids[ids.length - 1] == sessionOf.terminal;
        }
    }

    function refresh() {
        activeTerminal.call();
    }

    Timer {
        interval: 100
        repeat: true
        running: root.focused
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Tab switch: the tabs in order (sessionAtTab until -1), then the one next
    // to the active session
    property int step: 0
    property var tabs: []

    YakuakeCall {
        id: activeSession
        method: "activeSessionId"
        onFinished: returnValue => {
            tabAt.active = returnValue[0];
            root.tabs = [];
            tabAt.arguments = [0];
            tabAt.call();
        }
    }
    YakuakeCall {
        id: tabAt
        property int active: -1
        path: "/yakuake/tabs"
        method: "sessionAtTab"
        onFinished: returnValue => {
            const id = returnValue[0];
            if (id != -1) {
                root.tabs.push(id);
                tabAt.arguments = [root.tabs.length];
                tabAt.call();
                return;
            }
            const i = root.tabs.indexOf(tabAt.active);
            if (i == -1 || root.tabs.length < 2)
                return;
            raise.arguments = [root.tabs[(i + root.step + root.tabs.length) % root.tabs.length]];
            raise.call();
        }
    }
    YakuakeCall {
        id: raise
        method: "raiseSession"
        onFinished: root.refresh()
    }

    function switchTab(step) {
        root.step = step;
        activeSession.call();
    }

    // ── Keys, only while Yakuake has focus and the terminal is at that end ──

    component TabKey: KWin.ShortcutHandler {
        required property int step
        name: step < 0 ? "Yakuake Panes Previous Tab" : "Yakuake Panes Next Tab"
        text: step < 0 ? "Yakuake: previous tab (from the first terminal, only while Yakuake has focus)"
                       : "Yakuake: next tab (from the last terminal, only while Yakuake has focus)"
        sequence: step < 0 ? "Shift+Left" : "Shift+Right"
        onActivated: root.switchTab(step)
    }

    Loader {
        active: root.focused && root.atFirst
        sourceComponent: TabKey { step: -1 }
    }
    Loader {
        active: root.focused && root.atLast
        sourceComponent: TabKey { step: 1 }
    }
}
