#!/usr/bin/env python3
"""Render a QML file offscreen to a PNG, to look at a piece without installing it.

    python3 design/build/render_qml.py file.qml out.png [import paths...]

Pass design/dist/qml as an import path for `import Levves`. QML warnings are printed. Needs
PySide6 built against the system Qt (Fedora's python3-pyside6), so KDE's QML modules load too.
"""

import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from PySide6.QtCore import QTimer, QUrl, qInstallMessageHandler
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView

qInstallMessageHandler(lambda _type, _context, message: print("QML:", message))
app = QGuiApplication(sys.argv[:1])
view = QQuickView()
for path in sys.argv[3:]:
    view.engine().addImportPath(path)
view.setResizeMode(QQuickView.SizeViewToRootObject)
view.setSource(QUrl.fromLocalFile(os.path.abspath(sys.argv[1])))
if view.status() != QQuickView.Ready:
    sys.exit(1)
view.show()


def grab():
    view.grabWindow().save(sys.argv[2])
    app.quit()


QTimer.singleShot(400, grab)  # let images and text settle
app.exec()
