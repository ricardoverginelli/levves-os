#!/usr/bin/env python3
"""Build the "Levves" icon theme (run by apply.sh): Breeze Dark with neutral folders.

Breeze draws its folders in ColorScheme-Accent, which follows the selection color, so with Levves
every folder was amber; the accent is one thing per view (design/DESIGN.md Color). This theme
inherits Breeze Dark and replaces only its places and mimetype icons that use the accent, with the accent
fixed to `text-muted`. Prints "changed" when anything was written.
"""
import configparser
import importlib.util
import re
import shutil
from pathlib import Path

HERE = Path(__file__).resolve().parent
BREEZE = Path("/usr/share/icons/breeze-dark")
OUT = Path.home() / ".local/share/icons/Levves"

_spec = importlib.util.spec_from_file_location("levves_tokens", HERE.parents[3] / "design/dist/levves_tokens.py")
_tokens = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_tokens)
FOLDER = _tokens.TOKENS["color.text-muted"]
SETS = ("places/", "mimetypes/")  # folders, and the file views' inode-directory


def accent_to_folder(m):
    """An element painted in the accent, painted in the folder color instead (and not recolored)."""
    element = m.group(0).replace(' class="ColorScheme-Accent"', "").replace('class="ColorScheme-Accent" ', "")
    return element.replace("currentColor", FOLDER)


def build(dest):
    index = configparser.ConfigParser(interpolation=None, strict=False)
    index.optionxform = str
    index.read(BREEZE / "index.theme")
    places = [d for d in index["Icon Theme"]["Directories"].split(",") if d.startswith(SETS)]
    scaled = [d for d in index["Icon Theme"].get("ScaledDirectories", "").split(",") if d.startswith(SETS)]

    theme = configparser.ConfigParser(interpolation=None)
    theme.optionxform = str
    theme["Icon Theme"] = {"Name": "Levves", "Comment": "Breeze Dark with neutral folders",
                           "Inherits": "breeze-dark,hicolor", "Directories": ",".join(places)}
    if scaled:
        theme["Icon Theme"]["ScaledDirectories"] = ",".join(scaled)
    for directory in places + scaled:
        if index.has_section(directory):
            theme[directory] = dict(index[directory])
        source = BREEZE / directory
        if not source.is_dir():
            continue
        for icon in source.glob("*.svg"):
            svg = icon.read_text()  # follows Breeze's symlinks
            if "ColorScheme-Accent" not in svg:
                continue
            svg = re.sub(r"<[^>]*ColorScheme-Accent[^>]*>", accent_to_folder, svg)
            (dest / directory).mkdir(parents=True, exist_ok=True)
            (dest / directory / icon.name).write_text(svg)
    with open(dest / "index.theme", "w") as f:
        theme.write(f, space_around_delimiters=False)


def tree(path):
    return {p.relative_to(path): p.read_bytes() for p in path.rglob("*") if p.is_file()} if path.exists() else {}


staging = OUT.with_name("Levves.new")
shutil.rmtree(staging, ignore_errors=True)
staging.mkdir(parents=True)
build(staging)
if tree(staging) != tree(OUT):
    shutil.rmtree(OUT, ignore_errors=True)
    staging.rename(OUT)
    print("changed")
else:
    shutil.rmtree(staging)
