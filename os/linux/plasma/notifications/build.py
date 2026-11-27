#!/usr/bin/env python3
"""Install the Leaves notifications (org.leaves.notifications): Plasma's own
notifications applet QML with our changes (patches.py), on top of the stock
applet's C++ side, the same way as the Leaves tray (../tray/build.py).

The popups are created by the applet's Globals singleton, which Plasma compiles
into its module; a copy of the QML alone would still show stock popups. So the
package carries its own Globals (global/qmldir) and every file is rewired from
the module's Globals to it.

top-bar.js puts this applet in the Leaves tray in place of the stock one (never
both: each would show every popup). If a patch no longer matches (a Plasma
update changed the QML), the package is removed and the tray keeps the stock
applet; update patches.py for the new version. Prints "changed" when the
installed package changed.
"""

import json
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.dont_write_bytecode = True  # no __pycache__ in the repo
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "shared"))
import changes
import patches

ID = "org.leaves.notifications"
STOCK = "org.kde.plasma.notifications"
DEST = Path.home() / ".local/share/plasma/plasmoids" / ID
CACHE = Path.home() / ".cache/leaves/notifications"
UPSTREAM = (
    "https://raw.githubusercontent.com/KDE/plasma-workspace/v{version}/applets/notifications/{path}"
)
# The QML files of applets/notifications/CMakeLists.txt
QML = [
    "main",
    "CompactRepresentation",
    "DraggableDelegate",
    "FullRepresentation",
    "NotificationPopup",
    "global/Globals",
    "global/PulseAudio",
    "delegates/BaseDelegate",
    "delegates/DelegateHistory",
    "delegates/DelegateHistoryGrouped",
    "delegates/DelegatePopup",
    "components/ActionContainer",
    "components/Body",
    "components/DraggableFileArea",
    "components/EditContextMenu",
    "components/FooterLoader",
    "components/HeadingButtons",
    "components/Icon",
    "components/JobDetails",
    "components/JobIconItem",
    "components/JobItem",
    "components/ModelInterface",
    "components/NotificationHeader",
    "components/NotificationReplyField",
    "components/SpeedChart",
    "components/Summary",
    "components/ThumbnailStrip",
]

QMLDIR = """singleton Globals 1.0 Globals.qml
PulseAudio 1.0 PulseAudio.qml
"""


def plasma_version():
    out = subprocess.run(
        ["plasmashell", "--version"], capture_output=True, text=True, check=False
    ).stdout
    return out.split()[-1]


def fetch(version):
    """Upstream files for this version, cached so later runs work offline."""
    src = CACHE / version
    for path in ["metadata.json"] + [f"{q}.qml" for q in QML]:
        target = src / path
        if not target.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            with urllib.request.urlopen(
                UPSTREAM.format(version=version, path=path), timeout=30
            ) as r:
                target.write_bytes(r.read())
    return src


def use_leaves_globals(files):
    """Point every file at our Globals instead of the compiled one, and import
    global/ (as Leaves) where Leaves.Globals is used."""
    for name, text in files.items():
        if not name.endswith(".qml") or "/global/" in name:
            continue
        text = re.sub(
            r"(?<![\w.])(Notifications|NotificationsApplet)\.Globals\b", "Leaves.Globals", text
        )
        if re.search(r"\bLeaves\.Globals\b", text):
            depth = name.count("/") - 2  # contents/ui/X.qml is depth 0
            imports = list(re.finditer(r"^import .*\n", text, re.MULTILINE))
            line = f'import "{"../" * depth}global" as Leaves\n'
            text = text[: imports[-1].end()] + line + text[imports[-1].end() :]
        # The patches' Levves pieces and tokens (Theme.*, not Kirigami.Theme)
        if re.search(r"(?<![\w.])Theme\.", text) and "\nimport Levves\n" not in text:
            imports = list(re.finditer(r"^import .*\n", text, re.MULTILINE))
            text = text[: imports[-1].end()] + "import Levves\n" + text[imports[-1].end() :]
        files[name] = text


def main():
    version = plasma_version()
    try:
        src = fetch(version)
        files = {f"contents/ui/{q}.qml": (src / f"{q}.qml").read_text() for q in QML}
        patches.apply(files)
        use_leaves_globals(files)
        files["contents/ui/global/qmldir"] = QMLDIR
        # Our own QML: the panel's mixer and brightness (qml/)
        for qml in sorted((HERE / "qml").glob("*.qml")):
            files[f"contents/ui/leaves/{qml.name}"] = qml.read_text()
        metadata = json.loads((src / "metadata.json").read_text())
        metadata["KPackageStructure"] = "Plasma/Applet"
        metadata["KPlugin"]["Id"] = ID
        metadata["KPlugin"]["Name"] = "Leaves Notifications"
        # The tray turns on applets enabled by default; top-bar.js turns this
        # one on and the stock one off instead, so both never run together
        metadata["KPlugin"]["EnabledByDefault"] = False
        # Use the stock applet's C++ code (see the same line in ../tray/build.py)
        metadata["X-Plasma-RootPath"] = f"../applets/{STOCK}"
        files["metadata.json"] = json.dumps(metadata, indent=1, ensure_ascii=False)
    except (patches.PatchError, OSError) as e:
        files = None
        print(
            f"Leaves notifications NOT installed for Plasma {version} ({e}); the tray uses the stock ones",
            file=sys.stderr,
        )
    changes.report(changes.replace_tree(DEST, files))


main()
