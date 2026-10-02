#!/usr/bin/env python3
"""Synthesise Curfew's sound effects, ambience and music into assets/audio.

Everything is generated from scratch (noise, oscillators, simple filters) so
there are no third-party samples. Run from anywhere:

    python3 docs/tools/render_sounds.py            # all sounds
    python3 docs/tools/render_sounds.py step0 alert  # just these

Loops (steam_loop, ambience, music_low, music_high) are built to repeat
seamlessly; the game sets their loop points on load. The older chiptune effects
(bark, tug, pickup, lure_drop) come from render_assets.mjs and are not touched.
"""
import sys
import wave
from pathlib import Path

import numpy as np

SR = 22050
OUT = Path(__file__).resolve().parents[2] / "assets" / "audio"
rng = np.random.default_rng(7)


# ---------------------------------------------------------------- helpers

def t_of(seconds):
    return np.arange(int(seconds * SR)) / SR


def noise(seconds):
    return rng.uniform(-1.0, 1.0, int(seconds * SR))


def one_pole_lp(x, fc):
    a = 1.0 - np.exp(-2.0 * np.pi * fc / SR)
    y = np.empty_like(x)
    s = 0.0
    for i in range(len(x)):
        s += a * (x[i] - s)
        y[i] = s
    return y


def lp(x, fc, passes=1):
    for _ in range(passes):
        x = one_pole_lp(x, fc)
    return x


def hp(x, fc, passes=1):
    for _ in range(passes):
        x = x - one_pole_lp(x, fc)
    return x


def band(x, lo, hi):
    return lp(hp(x, lo), hi)


def decay(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def attack_release(n, a, r):
    e = np.ones(n)
    na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] = np.minimum(e[-nr:], np.linspace(1, 0, nr))
    return e


def sine(freq, n):
    f = np.broadcast_to(freq, (n,)) if np.ndim(freq) == 0 else freq
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def square(freq, n, duty=0.5):
    f = np.broadcast_to(freq, (n,)) if np.ndim(freq) == 0 else freq
    ph = np.cumsum(f) / SR % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def triangle(freq, n):
    f = np.broadcast_to(freq, (n,)) if np.ndim(freq) == 0 else freq
    ph = np.cumsum(f) / SR % 1.0
    return 4.0 * np.abs(ph - 0.5) - 1.0


def echo(x, delay_s, feedback, taps=4, circular=False):
    d = int(delay_s * SR)
    out = x.copy()
    for k in range(1, taps + 1):
        shifted = np.roll(x, d * k) if circular else np.concatenate([np.zeros(d * k), x])[: len(x)]
        out += shifted * (feedback ** k)
    return out


def loopify(x, overlap_s):
    """Make a seamless loop from x by crossfading its tail into its head."""
    n = len(x) - int(overlap_s * SR)
    o = len(x) - n
    out = x[:n].copy()
    fade = np.linspace(0, 1, o)
    out[:o] = x[:o] * fade + x[n:] * (1 - fade)
    return out


LOOPS = {"steam_loop", "ambience", "music_low", "music_high"}


def save(name, x, peak=0.9):
    x = np.asarray(x, dtype=np.float64).copy()
    if name not in LOOPS:
        # A few milliseconds of fade at each end so one-shots never click.
        k = min(len(x) // 4, int(0.004 * SR))
        x[:k] *= np.linspace(0, 1, k)
        x[-k:] *= np.linspace(1, 0, k)
    m = np.max(np.abs(x))
    if m > 0:
        x = x * (peak / m)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"{name}.wav  {len(x) / SR:5.2f}s  {len(pcm) * 2 // 1024} KB")


# ---------------------------------------------------------------- effects

def step(i):
    n = int(0.13 * SR)
    body = lp(noise(0.13), 700 + 150 * i, 2) * decay(n, 0.025)
    thump = sine(95 - 8 * i, n) * decay(n, 0.03) * 0.8
    tap = hp(noise(0.13), 2500) * decay(n, 0.004) * 0.25
    return body * 1.6 + thump + tap


def steam_loop():
    x = lp(hp(noise(3.4), 500, 2), 1800, 3)
    n = len(x)
    flutter = 1.0 + 0.18 * np.sin(2 * np.pi * np.arange(n) / SR * 1.7) + 0.1 * np.sin(2 * np.pi * np.arange(n) / SR * 4.3)
    return loopify(x * flutter, 0.4)


def bin_crash():
    n = int(0.9 * SR)
    hit = lp(noise(0.9), 3500) * decay(n, 0.05)
    clang = np.zeros(n)
    for f, amp, tau in [(523, 1.0, 0.22), (811, 0.8, 0.18), (1347, 0.55, 0.12), (2210, 0.35, 0.08)]:
        clang += sine(f * (1 + 0.004 * rng.standard_normal()), n) * decay(n, tau) * amp
    rattle = band(noise(0.9), 800, 4000) * decay(n, 0.12) * (np.sin(np.arange(n) / SR * 90) > 0.2)
    return hit * 1.2 + clang * 0.6 + rattle * 0.5


def meow():
    n = int(0.55 * SR)
    t = np.arange(n) / SR
    glide = 520 + 380 * np.sin(np.pi * np.clip(t / 0.5, 0, 1)) ** 0.8 - 80 * (t / 0.55)
    vib = 1 + 0.015 * np.sin(2 * np.pi * 6 * t)
    f = glide * vib
    voice = sine(f, n) + 0.5 * sine(f * 2, n) + 0.35 * sine(f * 3, n) + 0.2 * sine(f * 4, n)
    formant = lp(voice, 2200)
    env = attack_release(n, 0.05, 0.22) * (0.7 + 0.3 * np.sin(np.pi * t / 0.55))
    breath = hp(noise(0.55), 3000) * 0.05
    return (formant + breath) * env


def cat_hiss():
    n = int(0.5 * SR)
    x = band(noise(0.5), 2500, 9000)
    env = attack_release(n, 0.03, 0.2) * (0.6 + 0.4 * np.sin(np.pi * np.arange(n) / n))
    return x * env


def alert():
    # A curious "huh?": two quick rising notes.
    parts = []
    for f, dur in [(392, 0.09), (587, 0.15)]:
        n = int(dur * SR)
        parts.append(square(f, n, 0.3) * attack_release(n, 0.004, 0.05))
    return np.concatenate(parts)


def spotted():
    # A sharp, rising three-note alarm.
    parts = []
    for f, dur in [(659, 0.07), (880, 0.07), (1175, 0.16)]:
        n = int(dur * SR)
        parts.append((square(f, n, 0.5) * 0.7 + square(f * 1.5, n, 0.25) * 0.3) * attack_release(n, 0.003, 0.04))
    return echo(np.concatenate(parts + [np.zeros(int(0.1 * SR))]), 0.09, 0.4, 2)


def caught():
    # Police whistle (two warbling bursts) then a falling sting.
    def whistle(dur):
        n = int(dur * SR)
        t = np.arange(n) / SR
        f = 2750 + 90 * np.sin(2 * np.pi * 38 * t)
        trill = 0.75 + 0.25 * np.sign(np.sin(2 * np.pi * 38 * t))
        return (sine(f, n) + 0.3 * sine(f * 2, n) + hp(noise(dur), 3000) * 0.08) * attack_release(n, 0.01, 0.04) * trill
    gap = np.zeros(int(0.07 * SR))
    parts = [whistle(0.2), gap, whistle(0.4), np.zeros(int(0.1 * SR))]
    for f, dur in [(392, 0.18), (330, 0.18), (262, 0.18), (196, 0.55)]:
        n = int(dur * SR)
        parts.append((triangle(f, n) * 0.9 + square(f / 2, n, 0.25) * 0.3) * attack_release(n, 0.005, 0.1))
    return echo(np.concatenate(parts), 0.16, 0.3, 3)


def home():
    # A warm rising arpeggio with a held chord at the end.
    notes = [523.25, 659.25, 783.99, 1046.5]
    parts = []
    for f in notes:
        n = int(0.14 * SR)
        parts.append((triangle(f, n) + 0.3 * square(f, n, 0.25)) * attack_release(n, 0.005, 0.08))
    n = int(0.9 * SR)
    chord = sum(triangle(f, n) + 0.2 * sine(f * 2, n) for f in [523.25, 659.25, 783.99, 1046.5]) * attack_release(n, 0.01, 0.6)
    return echo(np.concatenate(parts + [chord]), 0.18, 0.35, 3)


def tick():
    n = int(0.05 * SR)
    return (sine(np.linspace(1500, 700, n), n) * decay(n, 0.012) + hp(noise(0.05), 3000) * decay(n, 0.004) * 0.3)


# ---------------------------------------------------------------- ambience

def ambience():
    dur, over = 16.0, 1.5
    total = dur + over
    n = int(total * SR)
    t = np.arange(n) / SR
    # A soft low drone: three sines whose levels breathe slowly. Frequencies and
    # LFO periods divide the loop length so it repeats seamlessly.
    drone = (sine(55.0, n) * (0.6 + 0.4 * np.sin(2 * np.pi * t / 8.0))
             + sine(82.5, n) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 16.0 + 1.0))
             + sine(110.0, n) * (0.35 + 0.35 * np.sin(2 * np.pi * t / 4.0 + 2.0)))
    # Faint electric hum from street lights.
    hum = (sine(100.0, n) * 0.5 + sine(200.0, n) * 0.25) * (0.7 + 0.3 * np.sin(2 * np.pi * t / 4.0))
    # A whisper of wind, kept very low and dark.
    wind = band(noise(total), 150, 600) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 8.0 + 1.0))
    # Crickets: clusters of short chirps at a few spots in the loop.
    crickets = np.zeros(n)
    for start in [1.0, 3.6, 6.2, 11.0, 13.4]:
        for k in range(int(rng.integers(3, 6))):
            m = int(0.045 * SR)
            f = 4200 + 150 * rng.standard_normal()
            chirp = sine(f, m) * attack_release(m, 0.004, 0.02)
            i0 = int((start + k * 0.085) * SR)
            crickets[i0:i0 + m] += chirp
    # A car passing far away, dark and rare.
    car = band(noise(total), 120, 650) * np.exp(-(((t - 9.0) / 1.6) ** 2))
    mix = drone * 0.5 + hum * 0.05 + wind * 0.12 + crickets * 0.05 + car * 0.18
    return loopify(mix, over)


# ---------------------------------------------------------------- music

BPM = 84
BEAT = 60.0 / BPM
SIXTEENTH = BEAT / 4.0
STEPS = 128  # eight bars
TOTAL = int(STEPS * SIXTEENTH * SR)

# Am - F - Dm - E, two bars each: (bass root, triad)
CHORDS = [
    (110.00, [220.00, 261.63, 329.63]),
    (87.31, [174.61, 220.00, 261.63]),
    (73.42, [146.83, 174.61, 220.00]),
    (82.41, [164.81, 207.65, 246.94]),
]


def put(buf, start, sig):
    """Add a sound into a circular buffer so tails wrap round to the start."""
    n = len(buf)
    start %= n
    end = start + len(sig)
    if end <= n:
        buf[start:end] += sig
    else:
        k = n - start
        buf[start:] += sig[:k]
        buf[: end - n] += sig[k:]


def at(step_index):
    return int(step_index * SIXTEENTH * SR)


def music_low():
    bass = np.zeros(TOTAL)
    pad = np.zeros(TOTAL)
    bell = np.zeros(TOTAL)
    for bar in range(8):
        root, triad = CHORDS[bar // 2]
        for step_in_bar, mult, length in [(0, 1, 3), (3, 1, 2), (6, 2, 2), (8, 1, 3), (11, 1, 2), (12, 1.5, 3)]:
            n = int(length * SIXTEENTH * SR * 1.3)
            f = root * mult
            tone = (square(f, n, 0.25) * 0.5 + sine(f, n) * 0.9)
            tone = lp(tone, 520) * decay(n, length * SIXTEENTH * 0.9) * attack_release(n, 0.004, 0.03)
            put(bass, at(bar * 16 + step_in_bar), tone)
    for chord in range(4):
        root, triad = CHORDS[chord]
        n = int(32 * SIXTEENTH * SR)
        sig = sum(triangle(f, n) + triangle(f * 1.004, n) for f in triad) * 0.18
        sig = lp(sig, 900) * attack_release(n, 0.9, 1.2)
        put(pad, at(chord * 32), sig)
        for k, st in enumerate([4, 13, 22, 27]):
            f = triad[(k * 2 + chord) % 3] * 2
            n2 = int(1.4 * SR)
            ping = (sine(f, n2) + 0.25 * sine(f * 2.01, n2)) * decay(n2, 0.28) * attack_release(n2, 0.003, 0.2)
            put(bell, at(chord * 32 + st), ping * 0.5)
    bell = echo(bell, SIXTEENTH * 3, 0.45, 4, circular=True)
    return bass * 1.0 + pad * 0.9 + bell * 0.45


def music_high():
    arp = np.zeros(TOTAL)
    drums = np.zeros(TOTAL)
    for bar in range(8):
        root, triad = CHORDS[bar // 2]
        notes = [triad[0] * 2, triad[1] * 2, triad[2] * 2, triad[1] * 2]
        for s in range(16):
            f = notes[s % 4] * (2 if (s // 4) % 2 else 1)
            n = int(0.17 * SR)
            tone = square(f, n, 0.125) * decay(n, 0.05) * attack_release(n, 0.002, 0.03)
            put(arp, at(bar * 16 + s), tone * (1.0 if s % 4 == 0 else 0.6))
        for s in range(0, 16, 2):
            n = int(0.05 * SR)
            hat = hp(noise(0.05), 6000) * decay(n, 0.012)
            put(drums, at(bar * 16 + s), hat * (0.5 if s % 4 == 2 else 0.3))
        for s in (0, 8, 10):
            n = int(0.22 * SR)
            f = np.linspace(135, 42, n)
            put(drums, at(bar * 16 + s), sine(f, n) * decay(n, 0.07) * 1.1)
        for s in (4, 12):
            n = int(0.14 * SR)
            snare = band(noise(0.14), 900, 6000) * decay(n, 0.04) + sine(190, n) * decay(n, 0.03) * 0.5
            put(drums, at(bar * 16 + s), snare * 0.55)
    arp = echo(arp, SIXTEENTH * 3, 0.35, 3, circular=True)
    return arp * 0.5 + drums * 0.9


# ---------------------------------------------------------------- main

SOUNDS = {
    "step0": (lambda: step(0), 0.7),
    "step1": (lambda: step(1), 0.7),
    "step2": (lambda: step(2), 0.7),
    "steam_loop": (steam_loop, 0.8),
    "bin_crash": (bin_crash, 0.9),
    "meow": (meow, 0.8),
    "cat_hiss": (cat_hiss, 0.7),
    "alert": (alert, 0.6),
    "spotted": (spotted, 0.7),
    "caught": (caught, 0.85),
    "home": (home, 0.8),
    "tick": (tick, 0.6),
    "ambience": (ambience, 0.9),
    "music_low": (music_low, 0.9),
    "music_high": (music_high, 0.9),
}

if __name__ == "__main__":
    wanted = sys.argv[1:] or list(SOUNDS)
    for name in wanted:
        fn, peak = SOUNDS[name]
        save(name, fn(), peak)
