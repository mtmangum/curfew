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

// Reclining along the bench's 2:1 screen slope. Separate leg silhouettes, a
// bent far knee, a supported head, and one loose arm make the pose read at 0.36x.
// Only the chest/coat and resting hand move with the breath; the head, hips,
// dangling arm and feet stay planted in both frames.
function lie(variant) {
  const f = new Cells(40, 24);
  const breath = variant === 1 ? -1 : 0;
  const poly = (points, ch) => {
    for (let y = 0; y < f.h; y++) for (let x = 0; x < f.w; x++) {
      let inside = false;
      for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
        const [xi, yi] = points[i], [xj, yj] = points[j];
        if ((yi > y + 0.5) !== (yj > y + 0.5) &&
            x + 0.5 < (xj - xi) * (y + 0.5 - yi) / (yj - yi) + xi) inside = !inside;
      }
      if (inside) f.set(x, y, ch);
    }
  };
  const row = (x, y, width, ch) => { for (let i = 0; i < width; i++) f.set(x + i, y, ch); };
  // Far leg bends gently at the knee, with a separate boot higher in the view.
  poly([[21,12],[26,10],[29,11],[30,14],[34,16],[34,18],[31,18],[27,15],[25,14],[22,16]], 't');
  poly([[23,12],[26,11],[28,12],[28,14],[26,13]], 'p');
  poly([[29,14],[33,16],[33,17],[30,16]], 'u');
  poly([[33,16],[36,16],[38,18],[38,19],[34,19],[33,18]], 'v');
  row(34,17,2,'t');
  // Near leg extends from the hip. The two shins separate before the ankles.
  poly([[20,15],[24,15],[28,17],[31,19],[33,20],[32,22],[29,21],[25,19],[21,18]], 't');
  poly([[22,16],[25,17],[29,19],[31,20],[29,20],[25,18]], 'p');
  row(28,20,2,'u');
  poly([[32,20],[34,21],[36,22],[37,22],[37,23],[33,23],[31,22]], 's');
  row(34,22,2,'h');
  // A slim coat follows the bench diagonal rather than making a humped body.
  poly([[8,7],[11,7],[12,10],[9,10]], 'S');
  poly([[11,7],[15,7+breath],[19,10],[23,12],[24,16],[21,17],[17,15],[11,12],[9,10]], 'b');
  poly([[11,8],[15,8+breath],[19,11],[21,12],[19,13],[14,11],[11,10]], 'a');
  poly([[11,11],[15,13],[21,15],[23,15],[22,17],[17,15],[12,13]], 'c');
  f.set(22,16,'e'); f.set(20,16,'o');
  // Open collar and dirty shirt; a small patch keeps the zombie's familiar rags.
  poly([[11,8],[13,8],[16,10],[15,12],[12,10]], 'w');
  row(21,13,2,'n'); f.set(21,14,'n');
  // Far arm lies across the abdomen; a dark sleeve edge separates it from the coat.
  poly([[12,7],[15,8+breath],[18,10+breath],[19,12],[17,13],[15,11],[13,10]], 'e');
  row(14,9+breath,2,'a'); row(16,10+breath,2,'b');
  row(17,12,2,'s'); f.set(18,11,'h');
  // Near arm drapes over the edge: short sleeve, elbow, long narrow forearm.
  poly([[11,11],[13,12],[14,14],[14,16],[12,16],[11,14]], 'c');
  row(12,12,1,'b'); f.set(13,14,'a');
  poly([[12,16],[14,16],[14,19],[13,21],[11,21],[11,20],[12,19]], 'S');
  row(12,17,1,'s'); f.set(12,20,'s');
  // Side-lying head rests in line with the shoulders, with a visible neck.
  // The face points upward: forehead -> nose -> lips -> beard along its top edge.
  poly([[3,4],[6,3],[8,4],[8,5],[10,5],[10,6],[9,7],[9,9],[7,10],[4,9],[2,7]], 's');
  poly([[4,4],[6,4],[7,5],[7,7],[5,7],[3,6]], 'h');
  poly([[2,3],[4,2],[6,2],[7,3],[5,4],[3,5],[3,7],[4,8],[3,9],[1,7],[1,4]], 'R');
  row(3,3,2,'r'); f.set(2,5,'q');
  poly([[6,8],[8,7],[9,7],[9,9],[7,10],[5,9]], 'd');
  row(6,5,2,'k'); f.set(9,5,'h'); f.set(8,7,'k');
  f.outline();
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
