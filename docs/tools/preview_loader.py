#!/usr/bin/env python3
"""Screenshot the web loading page in several states, without the engine.

    python3 docs/tools/preview_loader.py /some/output/folder

Needs an export in build/web (./serve.sh or deploy.sh makes one) and Google Chrome. It
takes build/web/index.html, swaps the engine for a stub that streams a chosen fraction of
the .wasm and .pck (so the page's own byte counters run), and has the stub call
window.curfewBoot / curfewReady like the game does. Writes desktop and phone-sized PNGs.
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
STUB = """<script>
const q = new URLSearchParams(location.search);
const frac = {wasm: +q.get('wasm') || 0, pck: +q.get('pck') || 0};
window.fetch = function (url) {
  const isW = String(url).endsWith('.wasm');
  const total = isW ? 39514754 : 3252428;
  const limit = Math.floor(total * (isW ? frac.wasm : frac.pck));
  let sent = 0;
  const rs = new ReadableStream({ pull(c) { return new Promise((r) => setTimeout(() => {
    if (sent >= limit) { return; }
    const n = Math.min(1 << 20, limit - sent); sent += n; c.enqueue(new Uint8Array(n)); r(); }, 5)); } });
  return Promise.resolve(new Response(rs, {status: 200}));
};
class Engine {
  static getMissingFeatures() { return []; }
  startGame() {
    ['index.wasm', 'index.pck'].forEach((u) => fetch(u).then((r) => { const rd = r.body.getReader(); (function go() { rd.read().then((x) => { if (!x.done) go(); }); })(); }));
    return new Promise(() => {});
  }
}
setTimeout(() => {
  const order = ['sound', 'city', 'streets'];
  const st = q.get('stage');
  if (st) { order.forEach((s, i) => { if (s === st) { window.curfewBoot(s, +q.get('f')); } else if (i < order.indexOf(st)) { window.curfewBoot(s, 1); } }); }
  if (q.get('ready')) { window.curfewReady(); }
}, 600);
</script>"""
SHOTS = [  # name, window size, query, virtual ms
    ("1-downloading", "1280,720", "wasm=0.4&pck=0", 2500),
    ("2-starting", "1280,720", "wasm=1&pck=1", 2500),
    ("3-building-city", "1280,720", "wasm=1&pck=1&stage=city&f=0.6", 2500),
    ("4-home", "1280,720", "wasm=1&pck=1&stage=streets&f=1&ready=1", 1300),
    ("phone-downloading", "400,800", "wasm=0.55&pck=0.2", 2500),
    ("phone-building", "400,800", "wasm=1&pck=1&stage=city&f=0.3", 2500),
]


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/loader").resolve()
    out.mkdir(parents=True, exist_ok=True)
    html = (ROOT / "build/web/index.html").read_text()
    marker = '<script src="index.js"></script>'
    assert marker in html, "export first (./serve.sh)"
    (out / "preview.html").write_text(html.replace(marker, STUB))
    # Phone sizes go through an iframe: headless Chrome will not make a window narrower than ~500px.
    (out / "phone.html").write_text('<body style="margin:0;background:#222"><iframe id=f width=390 height=780 style="border:0"></iframe>'
                                    '<script>document.getElementById("f").src="preview.html"+location.search;</script></body>')
    for name, size, query, ms in SHOTS:
        page = "phone.html" if name.startswith("phone") else "preview.html"
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--screenshot={out / (name + '.png')}",
                        f"--window-size={size}", f"--virtual-time-budget={ms}", f"file://{out / page}?{query}"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        print("wrote", out / (name + ".png"))


if __name__ == "__main__":
    main()
