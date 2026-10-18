#!/usr/bin/env python3
"""Download the MingCute icons listed in mingcute.txt into mingcute/<name>.svg.

The SVGs are committed, so apply.sh works offline; run this only after adding
names. Source: MingCute via Iconify's JSON package (Apache-2.0, see mingcute/LICENSE).
"""
import json
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCE = "https://cdn.jsdelivr.net/npm/@iconify-json/mingcute@1.2.8/icons.json"

names = [line.strip() for line in (HERE / "mingcute.txt").read_text().splitlines()
         if line.strip() and not line.startswith("#")]
with urllib.request.urlopen(SOURCE, timeout=60) as r:
    data = json.load(r)

missing = [n for n in names if n not in data["icons"]]
if missing:
    raise SystemExit(f"Not in MingCute: {', '.join(missing)}")

size = data.get("width", 24)
for name in names:
    body = data["icons"][name]["body"]
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">{body}</svg>\n'
    (HERE / "mingcute" / f"{name}.svg").write_text(svg)
print(f"Wrote {len(names)} icons to {HERE / 'mingcute'}")
