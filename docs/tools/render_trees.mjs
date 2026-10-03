// Draws the street trees (assets/sprites/tree/tree0..3.png): pixel-art foliage built from
// overlapping leaf clumps with a scalloped edge, shaded from the top left and speckled
// with light and dark leaves, over a barked trunk with a root flare and two limbs.
// Four kinds: a round oak, a tall elm, an autumn tree and a pine.
// 44x60 cells at 2 pixels per cell (88x120); StreetObject draws them at scale 0.5.
//
//   node docs/tools/render_trees.mjs               writes the PNGs
//   node docs/tools/render_trees.mjs preview a.png also a big contact sheet
import fs from 'node:fs';
import path from 'node:path';
import { Frame, rasterise } from './pixel_shapes.mjs';

const OUT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../../assets/sprites/tree/');
const W = 44, H = 60;

function rng(seed) { // small deterministic generator
  let a = seed >>> 0;
  return () => { a = (a + 0x6D2B79F5) >>> 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}

const LEAF = {
  oak:    { o: 0x0e1c14, d: 0x1b3a2a, m: 0x2b5a3c, l: 0x3f7a50, h: 0x66a56e },
  elm:    { o: 0x0e1c14, d: 0x1f3e2f, m: 0x2f6241, l: 0x468758, h: 0x72b47c },
  autumn: { o: 0x2a140c, d: 0x7a3a1a, m: 0xb4571f, l: 0xd9822e, h: 0xf2b84e },
  pine:   { o: 0x0a1913, d: 0x112e23, m: 0x1a4837, l: 0x2a694b, h: 0x4a9572 },
};
const BARK = { t: 0x33261a, b: 0x483524, u: 0x6a4e33, v: 0x86663f }; // shadow, bark, light, highlight

function trunk(f, cx, top, bottom, thick, r) {
  // tapering trunk, lit on the left, with bark grooves and a flared root
  for (let y = top; y <= bottom; y++) {
    const k = (y - top) / (bottom - top);
    const half = thick * (0.7 + 0.5 * k) + (y > bottom - 3 ? (y - (bottom - 3)) * 0.8 : 0);
    const sway = Math.sin(y * 0.35) * 0.6;
    for (let x = Math.floor(cx - half + sway); x <= Math.ceil(cx + half + sway); x++) {
      const t = (x - (cx + sway)) / (half + 0.5);
      f.set(x, y, t < -0.4 ? 'v' : t < 0.1 ? 'u' : t < 0.55 ? 'b' : 't');
    }
  }
  // bark grooves
  for (let y = top + 2; y < bottom - 1; y += 3) {
    const x = Math.round(cx + (r() - 0.5) * thick * 1.2);
    if (f.get(x, y) !== '.') f.set(x, y, 't');
    if (f.get(x, y + 1) !== '.' && r() < 0.6) f.set(x, y + 1, 't');
  }
}

function limb(f, x0, y0, x1, y1) {
  const n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0));
  for (let i = 0; i <= n; i++) {
    const x = Math.round(x0 + (x1 - x0) * i / n), y = Math.round(y0 + (y1 - y0) * i / n);
    f.set(x, y, 'u'); f.set(x + 1, y, 'b');
  }
}

// --- geometric, isometric pieces -----------------------------------------------------------
function inside(pts, x, y) {
  let c = false;
  for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    const [xi, yi] = pts[i], [xj, yj] = pts[j];
    if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) c = !c;
  }
  return c;
}
function poly(f, pts, ch) {
  const y0 = Math.floor(Math.min(...pts.map((p) => p[1]))), y1 = Math.ceil(Math.max(...pts.map((p) => p[1])));
  const x0 = Math.floor(Math.min(...pts.map((p) => p[0]))), x1 = Math.ceil(Math.max(...pts.map((p) => p[0])));
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) if (inside(pts, x + 0.5, y + 0.5)) f.set(x, y, ch);
}
// An isometric block: a lit top rhombus and two sides, the left one mid-tone and the right dark.
// `w` is half its width on screen, `hh` the height of its sides.
function block(f, cx, cy, w, hh, faces = { top: 'l', left: 'm', right: 'd', glint: 'h' }) {
  poly(f, [[cx - w, cy - hh], [cx, cy - hh + w / 2], [cx, cy + w / 2], [cx - w, cy]], faces.left);
  poly(f, [[cx + w, cy - hh], [cx, cy - hh + w / 2], [cx, cy + w / 2], [cx + w, cy]], faces.right);
  poly(f, [[cx, cy - hh - w / 2], [cx + w, cy - hh], [cx, cy - hh + w / 2], [cx - w, cy - hh]], faces.top);
  if (faces.glint) poly(f, [[cx - w * 0.1, cy - hh - w * 0.38], [cx + w * 0.5, cy - hh - w * 0.08], [cx - w * 0.1, cy + 0 - hh + w * 0.16], [cx - w * 0.6, cy - hh - w * 0.08]], faces.glint);
}
// A pyramid with a rhombus base: apex above the middle, a lit left face and a dark right face.
function pyramid(f, cx, baseY, rx, rise) {
  const ry = rx / 2, apex = [cx, baseY - rise];
  poly(f, [apex, [cx - rx, baseY], [cx, baseY + ry]], 'l');
  poly(f, [apex, [cx, baseY + ry], [cx + rx, baseY]], 'd');
  // a mid-tone band down the lit face, and a pale ridge along the left edge
  poly(f, [apex, [cx - rx * 0.35, baseY + ry * 0.25], [cx, baseY + ry]], 'm');
  poly(f, [apex, [cx - rx, baseY], [cx - rx * 0.86, baseY - ry * 0.08]], 'h');
}

function speckle(f, r, bounds) {
  // leaf texture: light leaves on the lit side, dark ones in the shade, a few gaps
  const [x0, y0, x1, y1] = bounds;
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
    const c = f.get(x, y);
    if (!'dml'.includes(c)) continue;
    const p = r();
    const lit = 1 - ((x - x0) / (x1 - x0) * 0.5 + (y - y0) / (y1 - y0) * 0.5); // 1 at top left
    if (c === 'm') { if (p < 0.10 + 0.12 * lit) f.set(x, y, 'l'); else if (p > 0.97 - 0.06 * (1 - lit)) f.set(x, y, 'd'); }
    else if (c === 'l') { if (p < 0.10 * lit + 0.03) f.set(x, y, 'h'); else if (p > 0.95) f.set(x, y, 'm'); }
    else if (c === 'd' && p < 0.08) f.set(x, y, 'm');
  }
}

function crownTop(f) {
  // brighten the upper left edge of the whole crown
  for (let y = 0; y < f.h; y++) for (let x = 0; x < f.w; x++) {
    const c = f.get(x, y);
    if ('ml'.includes(c) && f.get(x - 1, y - 1) === '.' && f.get(x, y - 1) !== '.') f.set(x, y, c === 'm' ? 'l' : 'h');
  }
}

// A trunk as a slim isometric column.
function column(f, cx, top, bottom, w) {
  poly(f, [[cx - w, top], [cx, top + w / 2], [cx, bottom + w / 2], [cx - w, bottom]], 'u');
  poly(f, [[cx + w, top], [cx, top + w / 2], [cx, bottom + w / 2], [cx + w, bottom]], 'b');
  poly(f, [[cx, top - w / 2], [cx + w, top], [cx, top + w / 2], [cx - w, top]], 'v');
  // bark grooves
  for (let y = top + 3; y < bottom - 1; y += 4) { f.set(Math.round(cx - w * 0.5), y, 't'); f.set(Math.round(cx + w * 0.5), y + 1, 't'); }
  // roots flaring a little at the foot
  poly(f, [[cx - w - 1, bottom - 1], [cx, bottom + w / 2 + 1], [cx, bottom + w / 2 - 1], [cx - w + 1, bottom - 3]], 'u');
  poly(f, [[cx + w + 1, bottom - 1], [cx, bottom + w / 2 + 1], [cx, bottom + w / 2 - 1], [cx + w - 1, bottom - 3]], 'b');
}

function crown(f, blocks, seed) {
  // back to front, so the nearer blocks overlap the ones behind
  const r = rng(seed);
  for (const [x, y0, w, hh] of [...blocks].sort((a, b) => a[1] - b[1] || a[0] - b[0])) {
    const y = y0 + 2;  // leave room above for the top tufts and the outline
    block(f, x, y, w, hh);
    // a few small leafy tufts softening the corners, so the geometry is only slight
    for (const [dx, dy] of [[-w, -hh], [w, -hh], [0, -hh - w / 2], [-w, 0], [w, 0]]) {
      if (r() < 0.55) f.blob(x + dx + (r() - 0.5) * 2, y + dy + (r() - 0.5) * 2, 1.6 + r() * 1.4, 1.4 + r(), dy < -hh * 0.5 ? ['h', 'l', 'm', 'm'] : ['l', 'm', 'd', 'd']);
    }
  }
}

function oak(variant) {
  const f = new Frame(W, H);
  column(f, 22, 36, 56, 3.2);
  crown(f, [[22, 13, 8, 6], [12, 18, 9, 7], [32, 18, 9, 7], [22, 22, 12, 8], [8, 27, 7, 6], [36, 27, 7, 6], [17, 31, 9, 7], [27, 31, 9, 7], [22, 35, 8, 5]], 5 + variant);
  return f;
}

function elm(variant) {
  const f = new Frame(W, H);
  column(f, 22, 34, 56, 2.8);
  crown(f, [[22, 8, 6, 5], [22, 16, 9, 7], [14, 22, 7, 6], [30, 22, 7, 6], [22, 26, 10, 8], [16, 33, 7, 5], [28, 33, 7, 5]], 9 + variant);
  return f;
}

function pine(variant) {
  const f = new Frame(W, H);
  column(f, 22, 48, 56, 2.2);
  // stacked pyramids, smaller towards the top
  for (const [by, rx, rise] of [[48, 17, 13], [41, 15, 12], [34, 13, 11], [27, 10.5, 10], [20, 8, 9], [13, 5.5, 8]]) pyramid(f, 22, by, rx, rise);
  return f;
}

const KINDS = [
  { name: 'tree0', pal: 'oak', make: () => oak(0) },
  { name: 'tree1', pal: 'elm', make: () => elm(0) },
  { name: 'tree2', pal: 'autumn', make: () => oak(5) },
  { name: 'tree3', pal: 'pine', make: () => pine(0) },
];

const frames = [];
fs.mkdirSync(OUT, { recursive: true });
for (const k of KINDS) {
  const f = k.make();
  const r = rng(99 + frames.length);
  speckle(f, r, [0, 2, W - 1, k.pal === 'pine' ? 52 : 42]);
  f.outline('o');
  const pal = { ...LEAF[k.pal], ...BARK, w: 0xffffff };
  fs.writeFileSync(path.join(OUT, k.name + '.png'), rasterise([f], 2, pal));
  frames.push({ f, pal });
}
console.log('wrote', KINDS.map((k) => k.name).join(', '), 'to', OUT);
if (process.argv[2] === 'preview') {
  // each tree with its own palette, side by side on a night-blue ground
  const fw = W * 8, fh = H * 8;
  const sheets = frames.map(({ f, pal }) => rasterise([f], 8, pal, 0x1b2038));
  // rasterise() makes one PNG per call: compose by writing separate files next to the sheet
  frames.forEach(({ f, pal }, i) => fs.writeFileSync(process.argv[3].replace('.png', `_${i}.png`), rasterise([f], 8, pal, 0x1b2038)));
  console.log('previews', process.argv[3].replace('.png', '_N.png'));
}
