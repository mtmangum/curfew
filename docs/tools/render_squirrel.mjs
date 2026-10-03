// Draws the squirrel sprites (assets/sprites/squirrel/*.png) from shapes: filled
// ellipses shaded from the top left, an automatic dark outline, then hand-placed details.
// Each frame is a 20x20 grid at 2 pixels per cell (40x40), shown in the game at
// scale 0.41 like the cat, so a cell is about a world pixel. Faces right.
//
//   node docs/tools/render_squirrel.mjs            writes the PNGs
//   node docs/tools/render_squirrel.mjs preview /some/folder.png   also a big contact sheet
import fs from 'node:fs';
import path from 'node:path';
import { Frame as Shapes, rasterise as raster } from './pixel_shapes.mjs';

const OUT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../../assets/sprites/squirrel/');
const N = 20;
const CELL = 2;

const PAL = {
  o: 0x26150e, // outline
  d: 0x5a3317, m: 0x91522a, l: 0xc07d3c, h: 0xe0a258, // fur, dark to light
  c: 0xf0dcb0, C: 0xc9ac7a, // cream belly and shade
  k: 0x0a0a0c, w: 0xffffff, n: 0x2a1212, p: 0xd98a86, // eye, glint, nose, tongue
  a: 0x6a3f1a, A: 0xe0ac4c, B: 0xb27a2a, // acorn cap, nut, nut shade
};

class Frame extends Shapes {
  constructor() { super(N, N); }
}

const FUR = ['h', 'l', 'm', 'd'];
const FUR2 = ['l', 'm', 'd', 'd'];
const TAIL = ['h', 'l', 'm', 'd'];

function tailPlume(f, pts, tip) {
  f.curve(pts[0], pts[1], pts[2], 1.6, 2.7, TAIL, 16);
  // a few light hairs along the outer edge and a pale tip
  f.set(tip[0], tip[1], 'c');
  f.set(tip[0] + 1, tip[1], 'h');
}

function sit(variant) {
  const f = new Frame();
  // tail: a big S-curve plume rising behind the body
  const flick = variant === 1 ? 1 : 0;
  tailPlume(f, [[7.5, 16.5], [-1.5, 12 + flick], [5 + flick, 1.8]], [5 + flick, 1]);
  f.curve([5, 3], [8.5, 0.6], [10, 3.4], 2.1, 1.4, TAIL, 8);
  // body, haunch, hind foot
  f.blob(11.8, 13.6, 3.7, 4.6, FUR);
  f.blob(9.4, 15.6, 3.0, 2.7, FUR2);
  f.blob(11.6, 18.4, 3.4, 1.2, ['d', 'd', 'd', 'd']);
  // head, snout, ears
  f.blob(14.6, 7.6, 3.4, 3.1, FUR);
  f.blob(17.6, 8.8, 1.9, 1.4, ['l', 'm', 'm', 'd']);
  f.blob(12.9, 4.4, 1.1, 1.8, FUR2);
  f.blob(16.3, 4.2, 1.1, 1.8, FUR);
  f.set(12, 2, 'd'); f.set(16, 2, 'd');
  // forepaws and the acorn
  const nib = variant === 1 ? -1 : 0;
  f.blob(15.7, 12.4 + nib, 1.3, 1.1, ['l', 'm', 'm', 'd']);
  f.blob(17.8, 12.2 + nib, 1.5, 1.7, ['A', 'A', 'B', 'B']);
  f.blob(17.8, 10.9 + nib, 1.8, 0.9, ['a', 'a', 'a', 'a']);
  f.outline();
  // belly, cheek, eye, nose
  f.paint(14.2, 14.2, 1.9, 3.4, ['m', 'c']);
  f.paint(12.8, 14.2, 1.6, 3.2, ['c', 'C']);
  f.set(16, 8, 'm'); f.set(15, 9, 'l');
  f.set(15, 7, 'k'); f.set(15, 6, 'k'); f.set(14, 6, 'w');
  f.set(19, 9, 'n');
  return f;
}

function chatter(variant) {
  const f = sit(variant);
  // mouth open: a dark gap and a pink tongue under the nose, acorn dropped
  f.set(17, 10, 'o'); f.set(18, 10, 'p'); f.set(19, 10, 'o');
  for (let y = 9; y <= 13; y++) for (let x = 16; x < N; x++) {
    if ('aAB'.includes(f.get(x, y))) f.set(x, y, '.');
  }
  f.set(17, 10, 'o'); f.set(18, 10, 'p'); f.set(19, 10, 'o');
  return f;
}

function run(variant) {
  const f = new Frame();
  const ext = variant === 0; // stretched out mid-leap, or gathered
  // a fluffy tail streaming behind, curling up at the end
  const lift = ext ? 0 : 1.2;
  f.curve([7.0, 11.0 + (ext ? 0 : -0.5)], [-2.0, 10.0 - lift], [2.6, 2.6 + lift], 2.2, 3.0, TAIL, 16);
  f.set(2, 2 + Math.round(lift), 'c'); f.set(3, 2 + Math.round(lift), 'h');
  if (ext) {
    f.blob(10.4, 11.8, 4.3, 2.8, FUR);       // body
    f.blob(7.6, 12.6, 2.9, 2.6, FUR2);        // haunch
    f.blob(15.2, 10.4, 3.2, 3.0, FUR);        // head
    f.blob(18.0, 11.4, 1.8, 1.3, ['l', 'm', 'm', 'd']); // snout
    f.blob(13.6, 7.5, 1.1, 1.7, FUR2);        // ears
    f.blob(16.4, 7.4, 1.0, 1.6, FUR);
    f.blob(4.4, 15.6, 2.8, 1.0, ['d', 'd', 'd', 'd']);   // hind feet pushed back
    f.blob(17.6, 14.6, 1.0, 1.8, ['m', 'm', 'd', 'd']);  // forelegs reaching
    f.blob(13.8, 14.8, 1.0, 1.4, ['m', 'm', 'd', 'd']);
  } else {
    f.blob(10.2, 11.2, 4.4, 3.4, FUR);
    f.blob(7.4, 12.8, 3.0, 2.8, FUR2);
    f.blob(14.4, 9.8, 3.1, 2.9, FUR);
    f.blob(17.2, 10.8, 1.8, 1.3, ['l', 'm', 'm', 'd']);
    f.blob(12.9, 7.0, 1.1, 1.7, FUR2);
    f.blob(15.6, 6.9, 1.0, 1.6, FUR);
    f.blob(9.6, 15.8, 4.0, 1.1, ['d', 'd', 'd', 'd']);
    f.blob(14.8, 14.6, 1.8, 1.0, ['m', 'm', 'd', 'd']);
  }
  f.outline();
  const hx = ext ? 15.2 : 14.4, hy = ext ? 10.4 : 9.8;
  f.paint(hx - 0.6, hy + 2.4, 2.4, 1.3, ['m', 'c']);
  f.set(Math.round(hx + 0.9), Math.round(hy - 1.5), 'k'); f.set(Math.round(hx + 0.2), Math.round(hy - 2.1), 'w');
  f.set(ext ? 19 : 18, ext ? 11 : 10, 'n');
  return f;
}

function climb(variant) {
  const f = new Frame();
  // clinging to a trunk on its right, head up, a bushy tail hanging behind
  const sway = variant === 0 ? 0 : 1.2;
  f.curve([8.4, 13.0], [0.5 - sway, 13.5], [2.8 + sway, 18.0], 2.6, 2.0, TAIL, 16);
  f.set(2 + Math.round(sway), 18, 'c'); f.set(3 + Math.round(sway), 18, 'h');
  f.blob(10.6, 11.4, 3.2, 4.8, FUR);        // body
  f.blob(8.8, 15.0, 2.4, 2.5, FUR2);        // haunch
  f.blob(12.4, 5.2, 3.0, 2.8, FUR);         // head tilted up
  f.blob(14.8, 3.8, 1.7, 1.3, ['l', 'm', 'm', 'd']);
  f.blob(10.6, 2.6, 1.1, 1.7, FUR2);        // ears
  f.blob(13.6, 1.8, 1.0, 1.6, FUR);
  const up = variant === 0 ? 0 : 1.2;
  f.blob(15.4, 7.6 - up, 1.1, 1.8, ['m', 'm', 'd', 'd']);     // forearms up the bark
  f.blob(15.6, 11.8 + up, 1.0, 1.5, ['m', 'm', 'd', 'd']);
  f.blob(11.6, 18.0 - up, 1.8, 1.0, ['d', 'd', 'd', 'd']);    // hind feet
  f.blob(15.2, 16.2 + up, 1.4, 1.0, ['d', 'd', 'd', 'd']);
  f.outline();
  f.paint(13.2, 11.0, 1.7, 3.8, ['m', 'c']);
  f.set(14, 4, 'k'); f.set(13, 3, 'w');
  f.set(16, 3, 'n');
  return f;
}

// --- output -------------------------------------------------------------------------------
const rasterise = (frames, cell, bg) => raster(frames, cell, PAL, bg);
const FRAMES = { sit0: sit(0), sit1: sit(1), chatter0: chatter(0), chatter1: chatter(1), run0: run(0), run1: run(1), climb0: climb(0), climb1: climb(1) };
fs.mkdirSync(OUT, { recursive: true });
for (const [name, f] of Object.entries(FRAMES)) fs.writeFileSync(path.join(OUT, name + '.png'), rasterise([f], CELL));
console.log('wrote', Object.keys(FRAMES).join(', '), 'to', OUT);
if (process.argv[2] === 'preview') {
  fs.writeFileSync(process.argv[3], rasterise(Object.values(FRAMES), 10, 0x1b2038));
  console.log('contact sheet', process.argv[3]);
}
