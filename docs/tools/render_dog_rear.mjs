// Stella up on her hind legs with her front paws against a tree, barking up at it:
// assets/sprites/dog/rear0.png and rear1.png (rear1 has her head thrown back, mouth open).
// Drawn with the shared shape tools in the same palette as the rest of her sprites
// (a 30x26 grid at 2 pixels per cell; the game shows it at scale 0.5). Faces right, with
// the tree on her right.
//
//   node docs/tools/render_dog_rear.mjs
//   node docs/tools/render_dog_rear.mjs preview /some/file.png   also a big contact sheet
import fs from 'node:fs';
import path from 'node:path';
import { Frame, rasterise } from './pixel_shapes.mjs';

const OUT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../../assets/sprites/dog/');
const W = 30, H = 26;
const PAL = {
  o: 0x252633, b: 0x555b68, d: 0x9299a5, e: 0xc7cbd1, // outline, shadow, fur, light fur
  f: 0xd84a62, g: 0xffd54a, // collar, tag
  c: 0x17131b, k: 0x0a0a0c, w: 0xffffff, p: 0xd98a86, // ear, eye, glint, tongue
};
const BODY = ['e', 'd', 'd', 'b'];
const LEG = ['d', 'd', 'b', 'b'];

function rear(open) {
  const f = new Frame(W, H);
  const hx = open ? 20.4 : 21.0, hy = open ? 3.6 : 4.6; // head
  // tail hanging behind
  f.curve([7.5, 17.5], [3.5, 18.5], [2.5, 22.5], 1.2, 0.8, ['d', 'b', 'b', 'b'], 8);
  // hind legs on the ground
  f.limb([10.0, 18.0], [10.8, 23.6], 1.9, 1.1, LEG);
  f.blob(12.3, 24.7, 2.7, 1.0, ['b', 'b', 'b', 'b']);
  f.limb([7.8, 17.5], [8.4, 23.6], 1.7, 1.0, LEG);
  f.blob(9.8, 24.7, 2.5, 1.0, ['b', 'b', 'b', 'b']);
  // long greyhound body rising diagonally from the haunch to the deep chest
  f.blob(9.6, 16.5, 3.6, 3.6, BODY);
  f.limb([10.5, 15.5], [16.5, 9.6], 3.0, 3.2, BODY);
  f.blob(17.6, 9.4, 3.4, 3.6, BODY);
  // neck and head
  f.limb([18.4, 8.2], [hx - 1.0, hy + 2.2], 2.0, 1.9, BODY);
  f.blob(hx, hy, 2.9, 2.5, BODY);
  f.blob(hx + 3.6, hy + (open ? -0.8 : 0.9), 2.5, 1.2, ['e', 'd', 'd', 'b']); // long snout
  f.blob(hx - 1.2, hy - 2.3, 0.9, 1.6, ['c', 'c', 'c', 'c']); // ear
  // front legs reaching up the trunk on the right
  f.limb([18.4, 11.2], [25.6, 8.4], 1.1, 0.9, LEG);
  f.limb([17.6, 12.6], [25.4, 11.6], 1.1, 0.9, LEG);
  f.blob(26.4, 8.2, 1.0, 1.0, ['d', 'd', 'b', 'b']);
  f.blob(26.2, 11.5, 1.0, 1.0, ['d', 'd', 'b', 'b']);
  f.outline();
  // lighter chest, collar and tag, eye, nose
  f.paint(17.2, 11.5, 2.2, 3.2, ['d', 'e']);
  const cx = Math.round(hx - 1.4), cy = Math.round(hy + 2.9);
  f.set(cx, cy, 'f'); f.set(cx + 1, cy + 1, 'f'); f.set(cx, cy + 1, 'f'); f.set(cx + 1, cy, 'f');
  f.set(cx + 1, cy + 2, 'g');
  f.set(Math.round(hx + 0.9), Math.round(hy - 0.6), 'k'); f.set(Math.round(hx + 0.4), Math.round(hy - 1.0), 'w');
  const nx = Math.round(hx + 6.0), ny = Math.round(hy + (open ? -0.8 : 0.9));
  f.set(nx, ny, 'k');
  if (open) { // mouth open mid-bark
    f.set(nx - 2, ny + 1, 'o'); f.set(nx - 1, ny + 1, 'p'); f.set(nx - 3, ny + 1, 'o'); f.set(nx, ny + 1, 'o');
    f.set(nx - 4, ny + 1, 'o');
  }
  return f;
}

const FRAMES = { rear0: rear(false), rear1: rear(true) };
fs.mkdirSync(OUT, { recursive: true });
for (const [name, f] of Object.entries(FRAMES)) fs.writeFileSync(path.join(OUT, name + '.png'), rasterise([f], 2, PAL));
console.log('wrote', Object.keys(FRAMES).join(', '), 'to', OUT);
if (process.argv[2] === 'preview') {
  fs.writeFileSync(process.argv[3], rasterise(Object.values(FRAMES), 12, PAL, 0x1b2038));
  console.log('contact sheet', process.argv[3]);
}
