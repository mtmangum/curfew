// Shared by the sprite generators (render_squirrel.mjs, render_dog_rear.mjs): a small
// grid of palette letters that can be filled with shaded ellipses and thick curves, given
// an automatic dark outline, and written out as a PNG.
import zlib from 'node:zlib';

export class Frame {
  constructor(w, h) {
    this.w = w; this.h = h;
    this.g = Array.from({ length: h }, () => Array(w).fill('.'));
  }
  set(x, y, ch) { if (x >= 0 && y >= 0 && x < this.w && y < this.h) this.g[y][x] = ch; }
  get(x, y) { return (x >= 0 && y >= 0 && x < this.w && y < this.h) ? this.g[y][x] : '.'; }
  // A shaded ellipse; tones run from lit (top left) to shadow (bottom right).
  blob(cx, cy, rx, ry, tones) {
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      const nx = (x + 0.5 - cx) / rx, ny = (y + 0.5 - cy) / ry;
      if (nx * nx + ny * ny > 1) continue;
      const t = nx * 0.55 + ny * 0.85; // > 0 on the shadow side
      const i = t < -0.35 ? 0 : t < 0.15 ? 1 : t < 0.55 ? 2 : 3;
      this.set(x, y, tones[Math.min(i, tones.length - 1)]);
    }
  }
  // A thick curve (quadratic bezier) made of blobs, radius easing from r0 to r1.
  curve(p0, p1, p2, r0, r1, tones, steps = 14) {
    for (let i = 0; i <= steps; i++) {
      const t = i / steps, u = 1 - t;
      this.blob(u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0], u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1], r0 + (r1 - r0) * t, r0 + (r1 - r0) * t, tones);
    }
  }
  // A straight limb: blobs along a line.
  limb(p0, p1, r0, r1, tones) {
    const n = Math.ceil(Math.hypot(p1[0] - p0[0], p1[1] - p0[1]) * 1.5);
    for (let i = 0; i <= n; i++) {
      const t = i / n;
      this.blob(p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t, r0 + (r1 - r0) * t, r0 + (r1 - r0) * t, tones);
    }
  }
  // Dark outline round everything drawn so far.
  outline(ch = 'o') {
    const filled = this.g.map((row) => row.map((c) => c !== '.'));
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      if (filled[y][x]) continue;
      if ([[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => (filled[y + dy] || [])[x + dx])) this.g[y][x] = ch;
    }
  }
  // Recolour only cells that are already part of the animal (belly, markings).
  paint(cx, cy, rx, ry, tones, outlineCh = 'o') {
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      const nx = (x + 0.5 - cx) / rx, ny = (y + 0.5 - cy) / ry;
      if (nx * nx + ny * ny > 1) continue;
      const here = this.get(x, y);
      if (here === '.' || here === outlineCh) continue;
      this.set(x, y, (nx * 0.55 + ny * 0.85) < -0.45 ? tones[1] : tones[0]);
    }
  }
}

const crcT = [...Array(256)].map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
const crc = (b) => { let c = ~0; for (const x of b) c = crcT[(c ^ x) & 255] ^ (c >>> 8); return ~c >>> 0; };
const chunk = (t, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([l, td, c]); };
export function png(w, h, px) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * 4 + 1)] = 0; Buffer.from(px.buffer, y * w * 4, w * 4).copy(raw, y * (w * 4 + 1) + 1); }
  const ih = Buffer.alloc(13); ih.writeUInt32BE(w, 0); ih.writeUInt32BE(h, 4); ih[8] = 8; ih[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ih), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}

// Frames side by side, `cell` pixels per grid cell, an optional background colour.
export function rasterise(frames, cell, pal, bg) {
  const fw = frames[0].w, fh = frames[0].h;
  const w = fw * cell * frames.length, h = fh * cell;
  const px = new Uint8Array(w * h * 4);
  frames.forEach((f, i) => {
    for (let y = 0; y < fh; y++) for (let x = 0; x < fw; x++) {
      const ch = f.g[y][x];
      for (let dy = 0; dy < cell; dy++) for (let dx = 0; dx < cell; dx++) {
        const o = ((y * cell + dy) * w + i * fw * cell + x * cell + dx) * 4;
        if (ch === '.') {
          if (bg) { px[o] = bg >> 16 & 255; px[o + 1] = bg >> 8 & 255; px[o + 2] = bg & 255; px[o + 3] = 255; }
          continue;
        }
        const c = pal[ch]; px[o] = c >> 16 & 255; px[o + 1] = c >> 8 & 255; px[o + 2] = c & 255; px[o + 3] = 255;
      }
    }
  });
  return png(w, h, px);
}
