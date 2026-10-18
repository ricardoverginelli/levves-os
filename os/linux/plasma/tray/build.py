#!/usr/bin/env python3
"""Install the Leaves system tray (org.leaves.systemtray): Plasma's own tray QML
with our changes, on top of the stock tray's C++ side (items, popups, status).

The package names the stock plugin in X-Plasma-RootPath, which makes Plasma
pair our QML with that plugin's C++ code. This downloads the tray QML for the
installed Plasma version, patches it (patches.py) and installs the package;
panels/top-bar.js adds it to the bar.

If a patch no longer matches (a Plasma update changed the QML), the package is
removed and top-bar.js falls back to the stock tray; update patches.py for the
new version. Prints "changed" when the installed package changed.
"""
import json
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import patches  # noqa: E402

ID = "org.leaves.systemtray"
DEST = Path.home() / ".local/share/plasma/plasmoids" / ID
CACHE = Path.home() / ".cache/leaves/systemtray"
UPSTREAM = "https://raw.githubusercontent.com/KDE/plasma-workspace/v{version}/applets/systemtray/{path}"
QML = ["AbstractItem", "BackgroundAppItem", "CompactApplet", "ConfigGeneral", "CurrentItemHighLight",
       "ExpandedRepresentation", "ExpanderArrow", "HiddenItemsView", "ItemLoader", "PlasmoidItem",
       "PlasmoidPopupsContainer", "PulseAnimation", "StatusNotifierItem", "SystemTrayState", "config", "main"]


def plasma_version():
    out = subprocess.run(["plasmashell", "--version"], capture_output=True, text=True).stdout
    return out.split()[-1]


def fetch(version):
    """Upstream files for this version, cached so later runs work offline."""
    src = CACHE / version
    paths = ["metadata.json", "main.xml"] + [f"qml/{q}.qml" for q in QML]
    for path in paths:
        target = src / path
        if not target.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            with urllib.request.urlopen(UPSTREAM.format(version=version, path=path), timeout=30) as r:
                target.write_bytes(r.read())
    return src


def snapshot(path):
    return {p.relative_to(path): p.read_bytes() for p in path.rglob("*") if p.is_file()} if path.exists() else {}


def main():
    version = plasma_version()
    before = snapshot(DEST)
    try:
        src = fetch(version)
        files = {f"contents/ui/{q}.qml": (src / f"qml/{q}.qml").read_text() for q in QML if q != "config"}
        files["contents/config/config.qml"] = (src / "qml/config.qml").read_text()
        files["contents/config/main.xml"] = (src / "main.xml").read_text()
        # A containment package must also carry applet/CompactApplet.qml: Plasma
        # wraps every tray item with it. Without it the items fall back to the
        # panel's version, open popups of their own and fight the tray's popup
        # (they flash open and closed). It uses AbstractItem from ui/.
        files["contents/applet/CompactApplet.qml"] = (src / "qml/CompactApplet.qml").read_text().replace(
            "import org.kde.plasma.plasmoid\n", 'import org.kde.plasma.plasmoid\n\nimport "../ui"\n', 1)
        patches.apply(files)
        metadata = json.loads((src / "metadata.json").read_text())
        metadata["KPackageStructure"] = "Plasma/Applet"
        metadata["KPlugin"]["Id"] = ID
        metadata["KPlugin"]["Name"] = "Leaves System Tray"
        # Use the stock tray's C++ code. Plasma finds that plugin through this
        # path, and also builds the path of the stock (built-in) QML from it;
        # the "../applets/" detour still finds the plugin file but turns the
        # built-in QML path into one that doesn't exist, so our QML is used.
        metadata["X-Plasma-RootPath"] = "../applets/org.kde.plasma.systemtray"
        files["metadata.json"] = json.dumps(metadata, indent=1, ensure_ascii=False)
    except (patches.PatchError, OSError) as e:
        shutil.rmtree(DEST, ignore_errors=True)
        print(f"Leaves tray NOT installed for Plasma {version} ({e}); the bar uses the stock tray", file=sys.stderr)
    else:
        shutil.rmtree(DEST, ignore_errors=True)
        for rel, text in files.items():
            (DEST / rel).parent.mkdir(parents=True, exist_ok=True)
            (DEST / rel).write_text(text)
    if snapshot(DEST) != before:
        print("changed")


main()
