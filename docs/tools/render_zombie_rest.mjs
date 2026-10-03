// Draws the zombies at rest (assets/sprites/zombie/sit.png and lie.png) from shapes: one
// slumped on the ground with his knees up, and one stretched out on a park bench with an arm
// trailing over the edge. Same ashen skin, matted hair and rags as the walking zombie
// (render_zombie.mjs). 2 pixels per cell, shown in the game at scale 0.36 like the others.
//
//   node docs/tools/render_zombie_rest.mjs            writes the PNGs
//   node docs/tools/render_zombie_rest.mjs preview /some/folder.png   also a big contact sheet
import fs from 'node:fs';
import path from 'node:path';
import { Frame, rasterise as raster } from './pixel_shapes.mjs';

const OUT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../../assets/sprites/zombie/');
const CELL = 2;

const PAL = {
  o: 0x1a1612,                                           // outline
  h: 0xcdbfb0, s: 0xb4a698, S: 0x948878, d: 0x7a6f62,    // ashen skin, light to shade
  r: 0x4a3a2c, R: 0x372b20, q: 0x2a2018, Q: 0x241c15,    // matted hair
  a: 0x8a7863, b: 0x6e5f4d, c: 0x574a3c, e: 0x4d4034,    // rag coat
  p: 0x544e48, t: 0x3e3a36, u: 0x2d2926, v: 0x24201d,    // trousers
  k: 0x241c15, w: 0x8d7d6a, n: 0x566270,                 // hollow eyes, grubby shirt, denim patch
};
const SKIN = ['h', 's', 'S', 'd'];
const HAIR = ['r', 'R', 'q', 'Q'];
const COAT = ['a', 'b', 'c', 'e'];
const PANTS = ['p', 't', 'u', 'v'];

class Cells extends Frame {
  constructor(w, h) { super(w, h); }
}

// Slumped on the ground, knees up, head hanging, hands dangling over his knees.
function sit(variant) {
  const f = new Cells(24, 28);
  const lean = variant === 1 ? 1 : 0;
  // legs: thighs up to the knees, shins down to the feet
  f.limb([8.5, 22.5], [7.2, 18.2], 2.1, 1.9, PANTS);
  f.limb([7.2, 18.2], [6.6, 25.6], 1.9, 1.6, PANTS);
  f.limb([15.5, 22.5], [16.8, 18.0], 2.1, 1.9, PANTS);
  f.limb([16.8, 18.0], [17.4, 25.4], 1.9, 1.6, PANTS);
  f.blob(6.2, 26.4, 2.2, 1.2, ['u', 'u', 'v', 'v']);     // a boot
  f.blob(17.9, 26.2, 2.2, 1.2, SKIN);                    // and a bare foot
  // body: slumped, a ragged coat
  f.blob(12 + lean * 0.4, 17.4, 5.4, 4.8, COAT);
  f.blob(12 + lean * 0.4, 21.2, 4.6, 2.2, PANTS);
  // arms hanging between the knees
  f.limb([7.0, 14.0], [7.8, 19.4], 1.55, 1.35, COAT);
  f.limb([17.0, 14.0], [16.4, 19.4], 1.55, 1.35, COAT);
  f.blob(8.0, 20.4, 1.25, 1.3, SKIN);
  f.blob(16.2, 20.4, 1.25, 1.3, SKIN);
  // head dropped forward, hair over it
  f.blob(12.2 + lean * 0.9, 10.2, 3.5, 3.3, SKIN);
  f.blob(12.2 + lean * 0.9, 8.4, 3.7, 2.5, HAIR);
  f.outline();
  // face: hollow eyes, a slack mouth; rips and a patch on the coat
  const hx = Math.round(12.2 + lean * 0.9);
  f.set(hx - 1, 10, 'k'); f.set(hx + 2, 10, 'k'); f.set(hx, 12, 'k'); f.set(hx + 1, 12, 'k');
  for (const [x, y] of [[9, 16], [10, 16], [14, 18], [13, 19], [11, 20]]) if (COAT.includes(f.get(x, y))) f.set(x, y, 'w');
  f.set(15, 16, 'n'); f.set(16, 16, 'n'); f.set(15, 17, 'n');
  return f;
}

// Stretched out along a bench (its long side runs down and to the right on screen, a rise of
// one for every two across), head at the top left, one arm hanging, a boot dangling over the end.
function lie(variant) {
  const f = new Cells(40, 24);
  const dy = variant === 1 ? 0.6 : 0;
  // legs along the slope, one knee a little bent
  f.limb([23.0, 14.0 + dy], [33.0, 19.0 + dy], 2.2, 2.0, PANTS);
  f.limb([22.0, 15.4 + dy], [30.0, 17.6 + dy], 2.0, 1.7, PANTS);
  f.blob(35.0, 20.0 + dy, 2.5, 1.5, ['u', 'u', 'v', 'v']);   // boot
  f.blob(32.8, 21.0 + dy, 2.0, 1.2, SKIN);                  // bare foot
  // body: coat
  f.limb([11.0, 9.2], [22.0, 14.4 + dy], 3.6, 3.5, COAT);
  // arm trailing off the front edge of the bench
  f.limb([15.0, 12.6], [16.0, 19.2], 1.5, 1.35, COAT);
  f.blob(16.1, 20.2, 1.3, 1.4, SKIN);
  // the other hand on his chest
  f.limb([13.0, 9.6], [18.0, 12.2], 1.4, 1.3, COAT);
  f.blob(18.6, 12.4, 1.2, 1.1, SKIN);
  // head, hair, face turned up to the sky
  f.blob(7.0, 6.8, 3.6, 3.4, SKIN);
  f.blob(5.4, 5.2, 3.3, 2.7, HAIR);
  f.outline();
  f.set(6, 7, 'k'); f.set(9, 8, 'k'); f.set(8, 10, 'k'); f.set(9, 10, 'k');
  for (const [x, y] of [[14, 10], [17, 12], [19, 13], [12, 9]]) if (COAT.includes(f.get(x, y))) f.set(x, y, 'w');
  f.set(20, 13, 'n'); f.set(21, 13, 'n'); f.set(20, 14, 'n');
  return f;
}

const rasterise = (frames, cell, bg) => raster(frames, cell, PAL, bg);
const FRAMES = { sit: sit(0), sit1: sit(1), lie: lie(0), lie1: lie(1) };
fs.mkdirSync(OUT, { recursive: true });
for (const [name, f] of Object.entries(FRAMES)) fs.writeFileSync(path.join(OUT, name + '.png'), rasterise([f], CELL));
console.log('wrote', Object.keys(FRAMES).join(', '), 'to', OUT);
if (process.argv[2] === 'preview') {
  // the frames differ in size, so draw each on its own sheet and put them side by side
  const sheets = [rasterise([FRAMES.sit, FRAMES.sit1], 10, 0x1b2038), rasterise([FRAMES.lie, FRAMES.lie1], 10, 0x1b2038)];
  fs.writeFileSync(process.argv[3], sheets[0]);
  fs.writeFileSync(process.argv[3].replace(/\.png$/, '_lie.png'), sheets[1]);
  console.log('contact sheets', process.argv[3]);
}
