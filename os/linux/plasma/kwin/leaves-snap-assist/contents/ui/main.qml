// KWin script entry point. The real code is in snapassist.qml: KWin's QML
// engine caches files by URL and never drops them when a script is reloaded,
// so a fresh query string makes each reload pick up edits without a re-login.
import QtQuick

Loader {
    source: Qt.resolvedUrl("snapassist.qml") + "?v=" + Date.now()
}
