#!/usr/bin/env python3
"""Write lists.json (games, exceptions) into the installed script's main.js,
in place of its /*LISTS*/ default: KWin scripts can't read files.

Usage: build.py <installed script folder>   (apply.sh runs it after copying)
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

lists = json.loads((HERE / "lists.json").read_text())
lists = {key: [entry.lower() for entry in lists.get(key, [])] for key in ("games", "exceptions")}

main = Path(sys.argv[1]) / "contents/code/main.js"
code = main.read_text()
start = code.index("/*LISTS*/")
end = code.index(";", start)
main.write_text(code[:start] + json.dumps(lists) + code[end:])
