#!/usr/bin/env python3
"""Refresh the sprite manifest; optionally package the gallery into a web build."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct

ROOT = Path(__file__).resolve().parents[2]


def build(output=None):
    groups = {}
    paths = list((ROOT / 'assets/sprites').glob('*/*.png')) + list((ROOT / 'web/gallery').glob('*/*.png'))
    for path in sorted(paths, key=lambda p: (p.parent.name, re.sub(r'\d+$', '', p.stem), int(re.search(r'\d+$', p.stem)[0]) if re.search(r'\d+$', p.stem) else -1)):
        data = path.read_bytes()
        width, height = struct.unpack('>II', data[16:24])
        state = re.sub(r'\d+$', '', path.stem)
        group = path.parent.name
        if group == 'rooftops':
            group = 'rooftopwater' if state == 'tank' else 'rooftophouse' if state == 'roof' else 'rooftopac'
        groups.setdefault(group, {}).setdefault(state, []).append({
            'name': path.stem, 'src': path.relative_to(ROOT).as_posix() + '?v=' + hashlib.sha256(data).hexdigest()[:12],
            'width': width, 'height': height,
        })
    manifest = 'window.CURFEW_SPRITES = ' + json.dumps(groups, indent=2) + ';\n'
    (ROOT / 'web/sprite-gallery-data.js').write_text(manifest)
    if output:
        output = Path(output).resolve()
        (output / 'web').mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / 'sprite-gallery.html', output / 'sprite-gallery.html')
        for name in ['sprite-gallery.css', 'sprite-gallery.js', 'sprite-gallery-data.js']:
            shutil.copy2(ROOT / 'web' / name, output / 'web' / name)
        for folder in ['sprites', 'fonts']:
            shutil.copytree(ROOT / 'assets' / folder, output / 'assets' / folder,
                            dirs_exist_ok=True, ignore=shutil.ignore_patterns('*.import'))
        shutil.copytree(ROOT / 'web/gallery', output / 'web/gallery', dirs_exist_ok=True, ignore=shutil.ignore_patterns('*.import'))
    print(f'Gallery: {len(groups)} sprite groups, {sum(len(v) for g in groups.values() for v in g.values())} frames')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', help='Package into this web build directory')
    build(parser.parse_args().output)
