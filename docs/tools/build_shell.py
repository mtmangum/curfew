#!/usr/bin/env python3
"""Build web/shell.html, the web export's loading page, from web/shell.template.html.

The template keeps Godot's $GODOT_* placeholders; this fills in the fonts and the
characters' walk frames as data URIs so the page needs no extra files (the export only
writes the engine, the pck and index.html). Run it after editing the template and commit
both files:

    python3 docs/tools/build_shell.py
"""
import base64
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def b64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def uri(path: Path) -> str:
    return "data:image/png;base64," + b64(path)


def frames(folder: str, names: list) -> list:
    return [uri(ROOT / "assets/sprites" / folder / f"{n}.png") for n in names]


sprites = {
    "nicole": frames("player", [f"walk{i}" for i in range(6)]),
    "stella": frames("dog", [f"walk{i}" for i in range(4)]),
    "cop": frames("cop", ["walk0"]),
}
html = (ROOT / "web/shell.template.html").read_text()
html = html.replace("{{FONT_SILKSCREEN}}", b64(ROOT / "assets/fonts/Silkscreen-Bold.ttf"))
html = html.replace("{{FONT_PIXELIFY}}", b64(ROOT / "assets/fonts/PixelifySans.ttf"))
html = html.replace("{{SPRITES}}", json.dumps(sprites))
(ROOT / "web/shell.html").write_text(html)
print("web/shell.html: %d KB" % (len(html) // 1024))
