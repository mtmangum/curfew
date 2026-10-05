# Pointer controls verification — 2026-10-05

Implements A1 from the [playability audit](../audits/2026-10-04/playability/REPORT.md). Goal: players can sneak, pause, resume and control the torch without a keyboard, including after automatic focus-loss pause.

## Changes

- Persistent Sneak and Pause buttons below the map; Torch appears on dark levels. Sneak and Torch show ON/OFF and stay synchronized with keyboard actions.
- Resume and Sound buttons remain interactive while the tree is paused. The overlay blocks input to the world.
- Action taps release held steering and consume GUI input. They do not create a walking destination. Action and item hit targets hide on the end banner to leave retry taps available.
- Pointer buttons enlarge independently of the fixed game canvas. Web sizing uses the canvas's CSS dimensions, so high-density displays do not shrink the targets. Width is bounded to the viewport. Keyboard controls remain available.
- README controls, handoff notes, changelog and the loader's sneak tip updated. Shell regenerated from its template.

This changes controls, not level difficulty or patrol rules. The wider mobile HUD/readability issue (A4) remains open: small world framing, clue text and the keyboard hint strip still use the existing scaling.

## Verification

Godot 4.7.2 on macOS; local working changes based on `62cf5d4a373747ad32b6ad05f728dcb479c24d9a`.

| Check | Result |
| --- | --- |
| Focused headless regressions: pointer_controls, pause, pointer, items, boot, memory_lifecycle, first_level, lightmap, clues | 9/9 passed |
| New fixture through actual GUI dispatch, normal native window | 14/14 assertions passed |
| Same fixture in a 390 × 844 native window | 14/14 assertions passed; controls and pause menu fit the letterboxed game area |
| Final focused pointer_controls rerun after button-width adjustment | Passed |
| Normal release Web export | Completed successfully |
| Chrome desktop, local normal Web export | Pointer Pause → Sound OFF/ON → Resume worked; pause overlay appeared and disappeared correctly |
| Chrome responsive 390 × 844 CSS-pixel viewport, touch emulation | Pause → Resume → Sneak ON worked; level 3 loaded and Torch ON → OFF worked; controls remained readable and inside the game area |
| Responsive rotation to 844 × 390 | Controls relaid out inside the game area; torch state persisted |

The fixture exercises sneak toggling and actual player state; torch input and keyboard synchronization; frozen run clock; sound control while paused; Resume; focus-loss recovery; treat use; Esc/P compatibility; hidden end-screen hit targets; a fresh level reset; and viewport/map/item-slot bounds. The existing pointer regression separately checks walking, held steering and wall cancellation. This is not a measured beginner completion rate or a physical phone test.

Final local Web pack SHA-256: `3b92dc1aa17d34d2469101e26e7c9dd5155c2e3d1c01bc9f97c5784db687adf3`.

Saved evidence: [regression groups](2026-10-05-pointer-controls/curfew-pointer-tests.log), [native GUI assertions](2026-10-05-pointer-controls/curfew-pointer-visual.log), [small-window assertions](2026-10-05-pointer-controls/curfew-pointer-small.log), [final focused rerun](2026-10-05-pointer-controls/curfew-pointer-final.log).

Native small-window renders (game area only; window letterboxing excluded):

- [Dark level controls](2026-10-05-pointer-controls/dark-controls.png)
- [Pause menu](2026-10-05-pointer-controls/paused.png)
- [Level 1 controls](2026-10-05-pointer-controls/first-level-controls.png)

Reproduce:

```sh
python3 docs/tools/run_tests.py pointer_controls pause pointer items boot memory_lifecycle first_level lightmap clues
mkdir -p /tmp/curfew-pointer-shots
POINTER_SMALL_WINDOW=1 POINTER_SHOTS=/tmp/curfew-pointer-shots /Applications/Godot.app/Contents/MacOS/Godot --path . --script docs/tools/test_pointer_controls.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release Web build/web/index.html
```

## Remaining device checks

A1's implementation is complete locally; its physical-device acceptance remains pending. On Android Chrome and iOS Safari, verify movement → sneak → item use → pause → resume → retry with touch only, switch away and return, and repeat after orientation changes and a level transition. Verify the torch on a dark level and audio unlocking after a gesture. Desktop viewport emulation does not establish those browser/OS lifecycle behaviors.

No commit, push or deployment performed for this implementation.
