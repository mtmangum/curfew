// Makes the corner characters (assets/sprites/cornerfolk/*.png), the people who stand on the corners under the
// neon on level 5 ("Neon Nose") and whom Stella stops to sniff. Three of them, two frames each, drawn from
// shaded blobs and limbs (pixel_shapes.mjs) at the size of the other street people (48 x 80, 2 px to a cell):
//   lean      a long pink coat and boots, hand on hip, swaying a little
//   umbrella  a teal trench coat under a purple umbrella, which tips a little
//   smoke     a leather jacket and big hair, a cigarette, and a puff of smoke drifting up
// All fully dressed, in the same cartoon style as the rest of the cast. Run after changing them:
//
//   node docs/tools/render_cornerfolk.mjs                 writes the PNGs
//   node docs/tools/render_cornerfolk.mjs preview a.png   also a big contact sheet
import fs from 'node:fs';
import path from 'node:path';
import { Frame, png, rasterise } from './pixel_shapes.mjs';

const OUT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../../assets/sprites/cornerfolk');
const W = 24, H = 40, CELL = 2;

// tones run from lit to shadow
const SKIN = ['s', 'S', 'k', 'K'];
const PAL = {
  o: 0x1a1220,
  s: 0xf3cba8, S: 0xe3ad86, k: 0xc58c68, K: 0x9c6a4c,                 // skin
  p: 0xff7ab8, P: 0xe0408c, q: 0xa8286a, Q: 0x7a1a4c,                 // pink coat
  h: 0x4a2f55, H: 0x35223f, i: 0x261830, I: 0x180f20,                 // dark violet hair
  b: 0x6a5f7c, B: 0x52485f, c: 0x181420, C: 0x100d16,                 // boots (mid grey-violet) and tights (near black)
  t: 0x4fd6c8, T: 0x2fa89e, u: 0x1f7a73, U: 0x16544f,                 // teal trench coat
  v: 0xa86bff, V: 0x7f45d6, w: 0x5a2fa0, W: 0x3f1f78,                 // purple umbrella
  d: 0x7a6e80, D: 0x5d5362, e: 0x433b48, E: 0x2f2934,                 // dark leather jacket
  r: 0xff9a3c, y: 0xffe08a,                                            // an ember, and its glow
  m: 0xd8d4e0, M: 0xb4b0c0, n: 0x8d8a9c,                               // smoke
  g: 0xffb3d6, G: 0xff8ac0, x: 0xffd6ea,                               // blonde-pink hair, and a highlight
  a: 0xf4ecf8, A: 0xd6cadf, z: 0xa99cb8, Z: 0x7b6e8c,                 // white boots
};
const SK = ['s', 'S', 'k', 'K'];

function legs(f, x, sway, boots) {
  f.limb([x - 2 + sway * 0.3, 27], [x - 2.4, 36], 1.6, 1.4, ['c', 'c', 'C', 'C']);
  f.limb([x + 2 - sway * 0.3, 27], [x + 2.4, 36], 1.6, 1.4, ['c', 'c', 'C', 'C']);
  f.blob(x - 2.5, 35, 2.2, 3.2, boots);  // boots up to the knee
  f.blob(x + 2.7, 35, 2.2, 3.2, boots);
  f.blob(x - 2.7, 37.6, 2.6, 1.2, boots);
  f.blob(x + 2.9, 37.6, 2.6, 1.2, boots);
}
function head(f, x, y, hair, hairBack = true) {
  if (hairBack) { f.blob(x - 3.5, y + 3.4, 1.8, 4.4, hair); f.blob(x + 3.5, y + 3.4, 1.8, 4.4, hair); }   // long hair falling either side of the face
  f.blob(x, y + 0.2, 3.2, 3.6, SK);                    // face
  f.blob(x, y - 2.5, 3.7, 1.9, hair);                  // fringe and crown
  f.set(Math.round(x - 1.4), Math.round(y + 0.6), 'o'); f.set(Math.round(x + 1.4), Math.round(y + 0.6), 'o');  // eyes
  f.set(Math.round(x - 0.5), Math.round(y + 2.3), 'P'); f.set(Math.round(x + 0.5), Math.round(y + 2.3), 'P');  // lips
}
// shoulders, a tapering coat and a neck: body(f, x, coat tones, how wide the skirt of the coat is)
function body(f, x, tones, skirt = 5.8) {
  f.blob(x, 22, skirt, 7.0, tones);
  f.blob(x, 16, 4.5, 3.4, tones);
  f.blob(x, 13.2, 1.7, 1.5, ['s', 'S', 'k', 'k']);
}

const WHITE_BOOTS = ['a', 'A', 'z', 'Z'];
const DARK_BOOTS = ['b', 'B', 'c', 'C'];

function lean(sway) {
  const f = new Frame(W, H), x = 12 + sway;
  legs(f, 12, sway, WHITE_BOOTS);
  body(f, x, ['p', 'P', 'q', 'Q']);
  f.limb([x - 4.4, 15.5], [x - 7.6, 20], 1.6, 1.4, ['p', 'P', 'q', 'q']);   // hand on hip: upper arm
  f.limb([x - 7.6, 20], [x - 4.6, 23], 1.4, 1.2, ['P', 'q', 'q', 'Q']);     // forearm
  f.limb([x + 4.4, 15.5], [x + 6.4, 25], 1.6, 1.4, ['p', 'P', 'q', 'q']);   // the other arm
  f.blob(x + 6.5, 26.4, 1.3, 1.3, SK);
  head(f, x, 8.6, ['g', 'G', 'q', 'q']);
  f.outline();
  return f;
}
function umbrella(tilt) {
  const f = new Frame(W, H), x = 12;
  legs(f, 12, 0, DARK_BOOTS);
  body(f, x, ['t', 'T', 'u', 'U'], 5.6);
  f.limb([x - 4.3, 15.5], [x - 5.6, 24], 1.5, 1.3, ['t', 'T', 'u', 'u']);
  f.limb([x + 4.3, 15.5], [x + 6.4, 19.5], 1.5, 1.3, ['t', 'T', 'u', 'u']);  // the arm that holds the umbrella
  f.blob(x + 6.6, 18.6, 1.3, 1.3, SK);
  head(f, x, 9.4, ['h', 'H', 'i', 'I']);
  f.limb([x + 6.6, 18.6], [x + 6.6 + tilt, 4.0], 0.6, 0.6, ['e', 'e', 'E', 'E']);   // handle
  f.blob(x + 4 + tilt, 4.0, 10.5, 3.6, ['v', 'V', 'w', 'W']);                         // canopy
  f.outline();
  return f;
}
function smoke(puff) {
  const f = new Frame(W, H), x = 12;
  legs(f, 12, 0, DARK_BOOTS);
  body(f, x, ['d', 'D', 'e', 'E'], 5.6);
  f.limb([x - 4.5, 15.5], [x - 6.0, 25], 1.6, 1.4, ['d', 'D', 'e', 'e']);
  f.limb([x + 4.5, 15.5], [x + 3.0, 12.0], 1.6, 1.3, ['d', 'D', 'e', 'e']);  // the hand with the cigarette, up to her mouth
  f.blob(x + 2.6, 11.4, 1.2, 1.2, SK);
  head(f, x - 0.5, 9.4, ['h', 'H', 'i', 'I']);
  f.blob(x - 0.5, 5.2, 5.2, 3.0, ['h', 'H', 'i', 'I']);                       // big hair
  f.set(Math.round(x + 3.6), 10, 'r'); f.set(Math.round(x + 4.1), 10, 'y');   // the ember
  f.outline();
  const sx = x + 4.7, sy = 8 - puff * 1.5;   // smoke after the outline: soft puffs rising and drifting
  f.blob(sx + puff * 0.8, sy - 1.5, 1.5, 1.4, ['m', 'm', 'M', 'M']);
  f.blob(sx + 1 + puff * 1.2, sy - 4.5, 2.0, 1.7, ['m', 'M', 'M', 'n']);
  f.blob(sx + 1.4 + puff * 1.5, sy - 8, 2.5, 2.0, ['M', 'M', 'n', 'n']);
  return f;
}

const sets = {
  lean: [lean(0), lean(0.8)],
  umbrella: [umbrella(0), umbrella(1.2)],
  smoke: [smoke(0), smoke(1)],
};
fs.mkdirSync(OUT, { recursive: true });
const all = [];
for (const [name, frames] of Object.entries(sets)) {
  frames.forEach((f, i) => { fs.writeFileSync(path.join(OUT, `${name}${i}.png`), rasterise([f], CELL, PAL)); all.push(f); });
}
console.log('wrote', all.length, 'frames to', OUT);
if (process.argv[2] === 'preview') {
  fs.writeFileSync(process.argv[3], rasterise(all, 6, PAL, 0x232638));
  console.log('contact sheet', process.argv[3]);
}
