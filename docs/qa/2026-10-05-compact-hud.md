# Small-screen playability follow-up — 2026-10-05

Implements A4 from the [playability audit](../audits/2026-10-04/playability/REPORT.md), locally on top of the verified A3 release `e98794b` and its release-record commit `a17dc66`. These changes are not yet committed or deployed. The production site still runs A3.

## Player behavior

Small canvases (under 1,000 pixels wide or 600 high) fill the available portrait or landscape area. Goal text is 17 screen units; movement hints, clue text, patrol warnings, retry instructions and menu bodies use 16. Primary actions are 48 units high and the item slot is 56 × 56. Map and Pause sit at the top; Sneak, Torch on dark levels and Stella's home request sit at the bottom. The map opens on demand, leaving more playfield visible by default. A long clue wraps above the bottom controls instead of overlapping them.

Pointer users see a short movement/home hint, an item USE badge and tap-based item explanations. Desktop keyboard users retain a shorter basic key strip. Pause → Controls provides the longer movement, Stella, item and keyboard reference. The pause backdrop separates that text from the game underneath. End banners wrap their retry instructions and hide old clues/toasts. Clue delivery, dwell and persistence are unchanged: A5 still needs interruption recovery and replay.

`Presentation.gd` reads CSS canvas dimensions at startup and on window-size changes, including while paused. Compact rendering uses 1.5 logical units per CSS pixel and scales the HUD independently. Desktop retains the 1280 × 720 framing; world projection/zoom and pointer-coordinate inversion are unchanged. Compact screens show a differently shaped area around the same centered player, rather than shrinking a 16:9 rectangle into portrait. Resizing does not recreate the world. There are no JavaScript size reads or repeated HUD layout calls during steady-state play.

## Verification

Godot 4.7.2, macOS. All **20 regression groups passed**: compact HUD, pointer controls, navigation, boot, map/phones, pause, clues, items, pointer movement, first level, second level, progression, memory lifecycle, light map, building fade, rooftops, chase, stealth, dog following and scent priority. See [runner output](2026-10-05-compact-hud/regressions.log).

The [compact fixture](../tools/test_compact_hud.gd) uses actual GUI event dispatch and measures resulting control rectangles rather than checking only assigned minimum sizes. All 14 checks pass headlessly and in the [native fixture](2026-10-05-compact-hud/native-fixture.log). The [final runner check](2026-10-05-compact-hud/final-compact-regression.log) includes the additional actual retry assertion.

| Check | Result |
| --- | --- |
| Fresh 390 × 844 portrait | Full canvas, readable goal/hints, distinct contained action targets of at least 44 screen pixels, 56-pixel item slot |
| Actual Sneak, Torch, Map and item taps | Correct state/action; no destination or held steering introduced |
| Long extinguisher explanation | Wraps within the screen, uses a tap instruction, avoids Home/item controls |
| Portrait → 844 × 390 while paused in Controls | HUD and help reflow; help retains 16-pixel text and 48-pixel buttons without shrinking |
| Back, Sound and Resume | Actual pointer dispatch works after rotation |
| Landscape clue | Fits to the left of Home and above the item slot |
| Ground tap after resizing | Reaches intended world destination within one unit |
| Compact → 1280 × 720 desktop | Restores framing, map and keyboard hints without stale anchors/double scale |
| Desktop → portrait end banner | Retry text fits; stale messages/actions hidden |
| Actual tap on the retry prompt | Restarts the scene, releases the old scene and retains the same house |
| Fresh landscape level 1 | Readable goal/essential actions; no unnecessary Torch control |

Native images were inspected at their actual output size: [portrait first level](2026-10-05-compact-hud/portrait-first-visit.png), [landscape first level](2026-10-05-compact-hud/landscape-first-visit.png), [dark portrait with item](2026-10-05-compact-hud/portrait-game.png), [portrait clue](2026-10-05-compact-hud/portrait-clue.png), [landscape clue](2026-10-05-compact-hud/landscape-clue.png), [portrait help](2026-10-05-compact-hud/portrait-controls-help.png), [landscape help](2026-10-05-compact-hud/landscape-controls-help.png) and [portrait retry](2026-10-05-compact-hud/portrait-retry.png).

The normal Web release export succeeded. Local pack SHA-256: `41df10cb504401de6a3cda8b8e3d89867f329d9d7cd16450b3efa7bfc9ea4ada`. Chrome DevTools responsive mode tested 390 × 844 and 844 × 390 on an isolated localhost origin, with device-pixel ratio 2 and browser zoom unchanged. A fresh portrait load filled the canvas with readable goal and controls; Pause and Controls worked by pointer. Rotating while paused reflowed the help, Back/Resume remained usable, and the Map button revealed the map in landscape. A reload directly in landscape also filled the canvas and retained usable controls. The inspected browser console showed engine startup messages and audio-unlock warnings before a user gesture, with no script errors. Native fixture screenshots above are separate from browser emulation.

## Remaining acceptance checks

Physical Android Chrome and iOS Safari at default zoom remain untested. Verify finger accuracy, browser bars/safe areas, focus loss/return, orientation changes and later-level lighting on those devices. Portrait exposes more vertical scenery than the old letterbox; the rendering and memory checks pass, but these tests do not establish phone frame times or battery cost. Observe beginners reading a clue, using an item and finding the help without coaching. A4's local implementation is complete; its release and physical-device acceptance remain pending. A5 is the next implementation item.

## Reproduce

```sh
python3 docs/tools/run_tests.py compact_hud pointer_controls navigation boot minimap pause clues items pointer first_level second_level levels memory_lifecycle lightmap fade roofs chase stealth_rules dog_follow scent_priority
COMPACT_SHOTS=docs/qa/2026-10-05-compact-hud /Applications/Godot.app/Contents/MacOS/Godot --fixed-fps 60 --path . --script docs/tools/test_compact_hud.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release Web build/web/index.html
python3 -m http.server 8077 --bind 127.0.0.1 --directory build/web
```
