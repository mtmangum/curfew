#!/bin/sh
# Export the web build and publish it to GitHub Pages: the build goes onto the
# gh-pages branch of `origin` as a single fresh commit (history is dropped each
# time, so the repo doesn't grow by a 40MB copy per deploy).
#   ./deploy.sh              export + publish
#   ./deploy.sh --skip-export   publish the existing build/web
# The site is served from the gh-pages branch (Settings > Pages), at
# https://<user>.github.io/<repo>/
set -e
cd "$(dirname "$0")"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [ "$1" != "--skip-export" ]; then
    mkdir -p build/web
    "$GODOT" --headless --path . --export-release Web build/web/index.html
fi
python3 docs/tools/build_sprite_gallery.py --output build/web
rev=$(git rev-parse --short HEAD)
remote=$(git remote get-url origin)
tmp=$(mktemp -d)
cp -R build/web/. "$tmp"
rm -f "$tmp"/*.import   # editor leftovers, not part of the game
cp docs/streetwise-ii-curfew-social.jpg "$tmp/cover.jpg"   # the picture a shared link shows (see og:image in web/shell.template.html)
touch "$tmp/.nojekyll"   # serve the files as they are
cd "$tmp"
git init -q -b gh-pages
git add -A
git -c user.name="$(git -C "$OLDPWD" config user.name)" -c user.email="$(git -C "$OLDPWD" config user.email)" \
    commit -q -m "Deploy $rev"
git push -f "$remote" gh-pages
rm -rf "$tmp"
echo "Published $rev to the gh-pages branch."
