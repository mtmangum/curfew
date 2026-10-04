#!/usr/bin/env python3
"""Cuts Stella's barks out of a real recording (docs/barks.m4a) into assets/audio/bark0..N.wav.

    python3 docs/tools/process_barks.py

docs/barks.m4a is a 27-second mono recording of a dog barking (the project owner's own). This finds
nothing by itself: the CLIPS table below lists where each bark starts and ends (found by looking at
the loudness of the recording: it has about forty barks, short ones about 0.12 s long, some alone,
some in runs of two to five; the low thump at 24.8 s is not a bark and is left out). Each clip is cleaned (rumble
cut below 110 Hz, the steady background hiss reduced, a few milliseconds of fade at each end),
brought to 22.05 kHz mono, and set to the same peak level so no bark is louder than another.

The game plays one at random (Main.bark -> AudioDirector.bark): bark0..bark2 are single barks and
bark3 is two in a row, so a string of barks is not one sample repeated. A few are enough.
Needs ffmpeg and numpy.
"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "docs" / "barks.m4a"
OUT = ROOT / "assets" / "audio"

PRE = 0.02    # seconds kept before the first onset
POST = 0.08   # and after the end, so the tail dies away naturally
PEAK = 0.85   # every bark is brought to the same peak, like the game's other sounds

# name: (first onset, end of the last bark in the clip), in seconds into the recording
CLIPS = {
    "bark0": (2.73, 2.84),     # a single bark
    "bark1": (13.44, 13.55),   # another single
    "bark2": (16.88, 17.00),   # a third single
    "bark3": (3.57, 3.92),     # two in a row
}


def cut(name: str, start: float, end: float, wav48: Path) -> None:
    t0 = max(start - PRE, 0.0)
    dur = (end + POST) - t0
    tmp = Path(tempfile.mkdtemp()) / f"{name}.wav"
    fade_out = 0.05
    chain = f"highpass=f=110,afftdn=nr=14:nf=-60,afade=t=in:d=0.003,afade=t=out:st={dur - fade_out:.3f}:d={fade_out}"
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-ss", f"{t0:.3f}", "-t", f"{dur:.3f}", "-i", str(wav48),
                    "-af", chain, "-ar", "22050", "-ac", "1", "-c:a", "pcm_s16le", str(tmp)], check=True)
    with wave.open(str(tmp)) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0
    gain = PEAK / max(np.max(np.abs(x)), 1e-9)
    y = np.clip(x * gain, -1.0, 1.0)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(22050)
        w.writeframes((y * 32767).astype(np.int16).tobytes())
    print(f"{name}.wav  {len(y) / 22050:4.2f}s  peak {np.max(np.abs(y)):.2f}  gain x{gain:.0f}")


def main() -> None:
    wav48 = Path(tempfile.mkdtemp()) / "barks48.wav"
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(SOURCE), "-ac", "1", "-ar", "48000", "-c:a", "pcm_s16le", str(wav48)], check=True)
    for name, (start, end) in CLIPS.items():
        cut(name, start, end, wav48)


if __name__ == "__main__":
    main()
