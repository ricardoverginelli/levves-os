#!/usr/bin/env python3
"""Fail if a Levves color is written out by hand instead of coming from design/dist/.

    python3 design/build/check_hardcoded.py

Looks for every color token's hex (#e9a23b, 0xFFE9A23B, "e9a23b") in the repo's tracked text files,
outside the places listed in SKIP. A file that can't use the generated files yet goes in DEFERRED
with the reason; the check also fails when a deferred file no longer has any, so the list stays true.
"""
import re
import subprocess
import sys
from pathlib import Path

import build

ROOT = build.DESIGN.parent

# Not on the Levves tokens (yet), or not code
SKIP = (
    "design/",            # the tokens themselves and their outputs
    "packages/",          # the suite keeps its Win95 tokens until its reskin
    "apps/suite/",
    "docs/",
    "tools/",
    "templates/",
)
SKIP_SUFFIXES = (".md", ".svg", ".png", ".jpg", ".gif", ".webp", ".ico", ".woff", ".woff2", ".sxb", ".jar")

DEFERRED = {
    # Loaded by plasmashell and KWin, which can't see design/dist/qml until the Plasma reskin installs it
    "os/linux/plasma/kwin-tabbox/leaves-switcher/contents/ui/main.qml": "Plasma reskin",
}


def color_hexes():
    tokens = build.resolve(build.flatten(build.load()))
    return sorted({t["value"][1:].lower() for t in tokens.values() if t["type"] == "color"})


def tracked_files():
    out = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-z"], capture_output=True, check=True).stdout
    return [f for f in out.decode().split("\0") if f]


def scan(files, hexes, read=lambda f: (ROOT / f).read_text()):
    alternatives = "|".join(hexes)
    pattern = re.compile(rf"(?i)(?:#|0x(?:ff)?|(?<=[\"']))({alternatives})\b")
    hits = {}
    for f in files:
        if f.startswith(SKIP) or f.endswith(SKIP_SUFFIXES):
            continue
        try:
            text = read(f)
        except (UnicodeDecodeError, FileNotFoundError, IsADirectoryError):
            continue
        for n, line in enumerate(text.splitlines(), 1):
            if pattern.search(line):
                hits.setdefault(f, []).append((n, line.strip()))
    return hits


def main():
    hits = scan(tracked_files(), color_hexes())
    bad = {f: lines for f, lines in hits.items() if f not in DEFERRED}
    stale = [f for f in DEFERRED if f not in hits]
    for f, lines in bad.items():
        for n, line in lines:
            print(f"{f}:{n}: {line[:120]}", file=sys.stderr)
    if bad:
        print("\nThese colors are Levves tokens: use design/dist/ for this platform (see design/DESIGN.md).",
              file=sys.stderr)
    for f in stale:
        print(f"{f} no longer hardcodes a token color: remove it from DEFERRED in check_hardcoded.py",
              file=sys.stderr)
    deferred = sum(len(hits[f]) for f in DEFERRED if f in hits)
    if not bad and not stale:
        print(f"no hardcoded token colors ({deferred} lines deferred to the reskin)")
    return 1 if bad or stale else 0


if __name__ == "__main__":
    sys.exit(main())
