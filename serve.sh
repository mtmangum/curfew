#!/bin/sh
# Export the game for the web and serve it at http://localhost:8060
# Usage: ./serve.sh        (export + serve)
#        ./serve.sh --skip-export
set -e
cd "$(dirname "$0")"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [ "$1" != "--skip-export" ]; then
    mkdir -p build/web
    "$GODOT" --headless --path . --export-release Web build/web/index.html
fi
python3 docs/tools/build_sprite_gallery.py --output build/web
echo "Serving on http://localhost:8060"
cd build/web && python3 -m http.server 8060
