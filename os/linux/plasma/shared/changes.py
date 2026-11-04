"""What the Plasma builds share: writing only what differs, so apply.sh knows when to restart.

Each build prints "changed" (report) when what it installed changed, and apply.sh restarts what
reads it. Import with `sys.path.insert(0, str(HERE.parent / "shared"))`, then `import changes`.
"""
import shutil
from pathlib import Path


def tree(path):
    """Every file under path, by its relative path, for comparing two installs."""
    path = Path(path)
    return {p.relative_to(path): p.read_bytes() for p in path.rglob("*") if p.is_file()} if path.exists() else {}


def write(path, text):
    """Write text to path unless it already holds exactly that; True when it wrote."""
    path = Path(path)
    if path.exists() and path.read_text() == text:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return True


def replace_tree(dest, files):
    """Make dest hold exactly files ({relative path: text}), or remove it when files is None.
    True when that changed anything."""
    dest = Path(dest)
    before = tree(dest)
    shutil.rmtree(dest, ignore_errors=True)
    for rel, text in (files or {}).items():
        (dest / rel).parent.mkdir(parents=True, exist_ok=True)
        (dest / rel).write_text(text)
    return tree(dest) != before


def report(changed):
    if changed:
        print("changed")
