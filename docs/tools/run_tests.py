#!/usr/bin/env python3
"""Run the headless checks in docs/tools/ and report which pass.

    python3 docs/tools/run_tests.py            # all of them
    python3 docs/tools/run_tests.py chase home # just these (names without test_)

Each test prints lines such as "...  ok: true". A test fails if it prints a line
with "ok: false" or ": false", hits a script error, times out (a script error in a
headless coroutine otherwise leaves Godot hanging), or prints nothing.
"""
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
# name: (extra args, timeout in seconds, fixed fps?)
TESTS = {
    "audio_cache": 120, "memory_lifecycle": 120, "stealth_rules": 120, "dog_cat": 120, "dog_gait": 200, "chase": 150, "pointer": 150,
    "start_safe": 150, "cop_pose": 120, "cat_sit": 120, "fade": 120, "footsteps": 120,
    "audio": 120, "investigate": 400, "lamp_light": 120, "home": 300, "obstacles": 150,
    "traffic": 300, "street_people": 300, "patrols": 600, "reachable": 600, "runlog": 150, "life": 150, "stella_stops": 300, "boot": 200, "minimap": 300, "levels": 300, "pause": 150, "fountain": 120, "plaza_zombies": 250, "roofs": 120, "tug": 120, "clues": 200,
}
NO_FIXED_FPS = {"reachable", "obstacles"}  # these don't depend on frame timing

def run(name: str):
    path = f"docs/tools/test_{name}.gd"
    cmd = [GODOT, "--headless"]
    if name not in NO_FIXED_FPS:
        cmd += ["--fixed-fps", "60"]
    cmd += ["--path", str(ROOT), "--script", path]
    env = dict(os.environ, CURFEW_LEVEL="2")  # the checks exercise the full city; test_levels asks for level 1 itself
    try:
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=TESTS[name], env=env)
        out = result.stdout
    except subprocess.TimeoutExpired as e:
        return False, ["TIMEOUT after %ds" % TESTS[name]] + ((e.stdout or b"").decode(errors="ignore").splitlines()[-4:] if e.stdout else [])
    lines = [l for l in out.splitlines() if not l.startswith(("Godot Engine", "Metal ", "WARNING:")) and l.strip() and not l.strip().startswith("at: ") and "leaked" not in l and "resources still in use" not in l]
    # Legacy checks print bare booleans, sometimes concatenated. Quoted dictionary
    # fields are diagnostic data; an explicit ok: result governs the whole line.
    boolean_result = re.compile(r'(?<!"):\s*((?:true|false)+)\b')
    bad = [l for l in lines if "ok: false" in l or "SCRIPT ERROR" in l or "Parse Error" in l
           or (name != "stealth_rules" and "ok: true" not in l
               and any("false" in m.group(1) for m in boolean_result.finditer(l)))]
    if result.returncode:
        bad.append("Godot exited with status %d" % result.returncode)
    # stealth_rules prints "(expect X)" lines instead of ok:
    if name == "stealth_rules":
        for l in lines:
            if "(expect " in l:
                value = l.split(": ", 1)[1].split(" (expect")[0].strip()
                want = l.split("(expect ")[1].rstrip(")").strip()
                if value.lower() != want.lower():
                    bad.append(l)
        if not any(l.startswith("T5") and "won" in l for l in lines):
            bad.append("T5 did not win")
        if not any(l.startswith("T1") and "caught" in l for l in lines):
            bad.append("T1 was not caught")
    if not lines:
        bad.append("(no output)")
    return not bad, (bad if bad else lines)

def main() -> int:
    names = sys.argv[1:] or list(TESTS)
    failed = 0
    for name in names:
        ok, lines = run(name)
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            failed += 1
            for l in lines[:8]:
                print("     ", l)
    print("\n%d of %d passed" % (len(names) - failed, len(names)))
    return 1 if failed else 0

if __name__ == "__main__":
    sys.exit(main())
