// Makes the zombie hobo sprites (assets/sprites/zombie/*.png) from the hobo's frames:
// ashen skin, messy hair instead of the cap, a torn dirty coat with a denim patch, ragged
// trousers and one bare foot, hollow eyes. Not green. (The flies are drawn in code, see
// StreetNpc.gd.) Run after changing the hobo frames:
//
//   node docs/tools/render_zombie.mjs                  writes the PNGs
//   node docs/tools/render_zombie.mjs preview a.png    also a big contact sheet
import zlib from 'node:zlib';
import fs from 'node:fs';
import path from 'node:path';
import { png } from './pixel_shapes.mjs';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../../assets/sprites/');
const FRAMES = ['shuffle0', 'shuffle1', 'shuffle2', 'shuffle3', 'rant0', 'rant1'];

function decode(file) {
  const d = fs.readFileSync(file);
  let pos = 8, w = 0, h = 0; const idat = [];
  while (pos < d.length) {
    const len = d.readUInt32BE(pos), type = d.toString('ascii', pos + 4, pos + 8), body = d.subarray(pos + 8, pos + 8 + len);
    pos += 12 + len;
    if (type === 'IHDR') { w = body.readUInt32BE(0); h = body.readUInt32BE(4); }
    if (type === 'IDAT') idat.push(body);
  }
  const raw = zlib.inflateSync(Buffer.concat(idat)), stride = w * 4 + 1, px = new Uint8Array(w * h * 4);
  for (let y = 0; y < h; y++) {
    if (raw[y * stride] !== 0) throw new Error('unexpected PNG filter in ' + file);
    raw.copy(px, y * w * 4, y * stride + 1, (y + 1) * stride);
  }
  return { w, h, px };
}

const hex = (c) => [(c >> 16) & 255, (c >> 8) & 255, c & 255];
const key = (r, g, b) => (r << 16) | (g << 8) | b;
// hobo colour -> zombie colour
const REMAP = new Map([
  [0x7a2f2f, 0x372b20], [0x4f1f1f, 0x241c15],   // the cap becomes matted hair
  [0xc99a7a, 0xb4a698],                          // skin: pale and ashen
  [0x9aa0a6, 0x77746d],                          // beard: grey stubble
  [0x3d3d27, 0x4d4034], [0x5b5a3a, 0x6e5f4d],   // sleeves and coat: dirty brown rags
  [0x7a4a3a, 0x566270],                          // the patch: a scrap of denim
  [0x6b4a2a, 0x6e5f4d], [0x58a068, 0x6e5f4d],   // the carrier bag goes
  [0x3a3a45, 0x3e3a36], [0x2a2a33, 0x2d2926],   // trousers: faded, torn
]);
const OUTLINE = 0x1a1612, SKIN = 0xb4a698, SHIRT = 0x8d7d6a, DARK = 0x241c15;

function zombie(frame) {
  const { w, h, px } = decode(path.join(ROOT, 'hobo', frame + '.png'));
  const cw = w / 2, ch = h / 2;
  // cell grid (2x2 pixels per cell), recoloured
  const g = Array.from({ length: ch }, (_, y) => Array.from({ length: cw }, (_, x) => {
    const i = (y * 2 * w + x * 2) * 4;
    if (px[i + 3] === 0) return null;
    const c = key(px[i], px[i + 1], px[i + 2]);
    return REMAP.has(c) ? REMAP.get(c) : c;
  }));
  const set = (x, y, c) => { if (x >= 0 && y >= 0 && x < cw && y < ch) g[y][x] = c; };
  const get = (x, y) => (g[y] || [])[x] ?? null;
  const COAT = 0x6e5f4d;
  // hollow eyes and a slack mouth
  set(10, 8, DARK); set(13, 8, DARK); set(11, 10, DARK); set(12, 10, DARK);
  // holes in the coat with the grubby shirt showing, and torn edges
  for (const [x, y] of [[8, 17], [9, 17], [14, 21], [13, 20], [11, 24], [12, 24], [16, 18]]) if (get(x, y) === COAT) set(x, y, SHIRT);
  for (const [x, y] of [[10, 19], [15, 23], [8, 22]]) if (get(x, y) === COAT) set(x, y, OUTLINE);
  // a ragged hem: notches along the bottom of the coat
  for (const x of [8, 10, 13, 15]) { if (get(x, 27) !== null && get(x, 27) !== OUTLINE) set(x, 27, null); }
  for (const x of [9, 14]) { if (get(x, 26) === COAT) set(x, 26, 0x4d4034); }
  // trousers frayed at the bottom, and one bare foot
  for (const x of [7, 9, 13, 15]) { if (get(x, 35) !== null && get(x, 35) !== OUTLINE) set(x, 35, 0x2d2926); }
  for (let y = 36; y <= 38; y++) for (let x = 5; x <= 11; x++) if (get(x, y) === 0x2a2420) set(x, y, y === 38 ? OUTLINE : SKIN);
  // out to pixels
  const out = new Uint8Array(w * h * 4);
  for (let y = 0; y < ch; y++) for (let x = 0; x < cw; x++) {
    const c = g[y][x];
    if (c === null) continue;
    const [r, gg, b] = hex(c);
    for (let dy = 0; dy < 2; dy++) for (let dx = 0; dx < 2; dx++) {
      const o = ((y * 2 + dy) * w + x * 2 + dx) * 4;
      out[o] = r; out[o + 1] = gg; out[o + 2] = b; out[o + 3] = 255;
    }
  }
  return { w, h, out };
}

fs.mkdirSync(path.join(ROOT, 'zombie'), { recursive: true });
const sheets = [];
for (const f of FRAMES) {
  const z = zombie(f);
  fs.writeFileSync(path.join(ROOT, 'zombie', f + '.png'), png(z.w, z.h, z.out));
  sheets.push(z);
}
console.log('wrote', FRAMES.join(', '), 'to assets/sprites/zombie');
if (process.argv[2] === 'preview') {
  const scale = 6, w = sheets[0].w * scale * sheets.length, h = sheets[0].h * scale;
  const px = new Uint8Array(w * h * 4);
  sheets.forEach((z, n) => {
    for (let y = 0; y < h; y++) for (let x = 0; x < z.w * scale; x++) {
      const o = (y * w + n * z.w * scale + x) * 4, s = (Math.floor(y / scale) * z.w + Math.floor(x / scale)) * 4;
      if (z.out[s + 3]) { px[o] = z.out[s]; px[o + 1] = z.out[s + 1]; px[o + 2] = z.out[s + 2]; px[o + 3] = 255; }
      else { px[o] = 0x1b; px[o + 1] = 0x20; px[o + 2] = 0x38; px[o + 3] = 255; }
    }
  });
  fs.writeFileSync(process.argv[3], png(w, h, px));
  console.log('contact sheet', process.argv[3]);
}
