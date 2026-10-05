# Guidance and HUD playability follow-up

Implemented locally on 2026-10-05 after `a17dc66`, alongside unreleased A4–A8.
No commit, push or deployment was performed. This addresses the house/bubble art,
overlapping arrows, passive level 1 progress and crowded controls raised after the
[playability audit](../audits/2026-10-04/playability/REPORT.md).

## Resulting behavior

Stella's home lead stops at the 80-unit leash limit and waits for Nicole. Both the
direct scent tug and the secondary leash correction can no longer move Nicole
during a home lead, including the frame when the lead ends. Active walking still
lets Stella follow her collision-aware local waypoints around obstacles. Cat,
squirrel and other ordinary distraction pulls remain. Level 1 keeps its existing
forgiving hazards, home band and hint intervals; this change requires participation
without increasing early punishment.

One outlined gold arrow below Stella replaces the overlapping arrow/scent wisps.
The stationary thought bubble above her uses two thought dots, a light background
and a simpler house with a lit door. The style resource is reused between draws.
The gallery's house and four thought-bubble PNGs were regenerated from the same
code, and its manifest was rebuilt (24 groups, 203 frames).

Pause and Sneak are the two persistent first-level action buttons. Torch appears
on dark levels and the item slot appears when carrying an item or showing an effect.
Map and Stella's home request are available in Pause alongside Controls and Field
guide. Maps start closed on desktop too. The temporary Close map action sits below
the map on compact screens, clear of the Life label; background instructions and
toasts hide while the map is open. H and M shortcuts remain. Home requests show
queued, active, cooldown and found states. The clue and field guide explain that
the player must walk and where to request another hint.

## Verification

Godot 4.7.2, fixed 60 FPS simulations.

- [Headless focused checks](2026-10-05-guidance-and-hud/headless.log): **15 pass**,
  including real GUI event dispatch, menu requests without ground steering, map
  close/life-label separation, portrait and small landscape targets, eight repeated
  home-lead directions with zero idle-owner movement, bounded leads, an overextended
  leash and field-guide teaching.
- [Initial regressions](2026-10-05-guidance-and-hud/regressions.log): 20/21 passed.
  The old Stella fixture expected home hints to haul Nicole. Its assertion now
  verifies the intended stationary owner, and waits through the longer first clue.
  [Five follow-up groups](2026-10-05-guidance-and-hud/regressions-followup.log),
  [four teaching/tooling groups](2026-10-05-guidance-and-hud/teaching-followup.log),
  [final layout groups](2026-10-05-guidance-and-hud/layout-followup.log) and
  [gallery check](2026-10-05-guidance-and-hud/gallery-check.log) and
  [tug-sound check](2026-10-05-guidance-and-hud/tug-followup.log) all pass. This covers
  **23 distinct selected regression groups**, including memory lifecycle.
- [Native visual fixture](2026-10-05-guidance-and-hud/native.log): 15 state checks
  pass. Reviewed portrait play, Pause and Map; 844×390 and 640×320 Pause layouts;
  four home-arrow headings and desktop Field guide. Native preparation uses button
  callbacks because window resizing/focus made injected native events unreliable.
  It establishes presentation, **not native pointer dispatch**; headless checks
  dispatch actual GUI events. Gameplay captures resume immediately before drawing
  to prevent unrelated focus-loss auto-pause from obscuring the fixture.
- [Active routes](2026-10-05-guidance-and-hud/active-routes.json): **12/12 wins**,
  six seeds each for rush and resourceful, with matching initial signatures between
  policies. Median homecoming is 26.1 seconds for rush and 24.15 for resourceful.
- [Idle routes](2026-10-05-guidance-and-hud/idle-runs.json): six real level 1 scenes,
  three simulated minutes each, normal traffic/distractions and no player input.
  None reached home; all remained `idle_observation`, with 12–14 scent hints each.
  The maximum displacement is 37.3 units; movements in two seeds come from retained
  ordinary distractions. Isolated home-lead tests show zero owner movement.
- [Level 1 replay](2026-10-05-guidance-and-hud/level1-replays.json): both pairs match
  the entire JSON record. [Comparison checks](2026-10-05-guidance-and-hud/comparisons.log)
  record outcomes, source identity, fresh tutorial profiles and exact replay equality.
- [Web export](2026-10-05-guidance-and-hud/export.log) succeeds without script/parse
  errors. Local pack SHA256:
  `76d8b1167d45e49d11090b6d6c936cdc4a54751a7411eac232d0f0ef76f55f6f`.

Tutorial memory was another reproducibility input: the first home lead lasts six
seconds, later leads 2.6 seconds. Bot runs previously shared the seen set, which
could alter later physical movement despite identical actor seeds. Each bot run
and route profile now resets teaching memory without writing player saves and
records `tutorial_profile: fresh visitor`. The idle fixture does the same. Historical
A8 evidence remains unchanged; the current records describe the revised sources.

Legacy coroutine fixture exit-resource warnings remain in raw logs. The dedicated
memory-lifecycle group passes; this work does not establish warning-free teardown.
Bots know the destination, so active wins are route feasibility evidence, not
first-time discovery or retention measurements. Browser runtime, real touch input,
physical phone layouts and uncoached beginner observation remain pending. No local
server was started and no release is claimed.

## Visual evidence

[Portrait play](2026-10-05-guidance-and-hud/portrait-play.png),
[portrait Pause](2026-10-05-guidance-and-hud/portrait-pause.png),
[portrait Map](2026-10-05-guidance-and-hud/portrait-map.png),
[small landscape Pause](2026-10-05-guidance-and-hud/landscape-pause-320.png),
[east cue](2026-10-05-guidance-and-hud/cue-east.png),
[north cue](2026-10-05-guidance-and-hud/cue-north.png),
[west cue](2026-10-05-guidance-and-hud/cue-west.png),
[south cue](2026-10-05-guidance-and-hud/cue-south.png),
[desktop Field guide](2026-10-05-guidance-and-hud/desktop-home-guide.png).

## Reproduce

```sh
python3 docs/tools/run_tests.py guidance_hud navigation compact_hud pointer_controls pause first_level second_level first_walk tug scent_priority dog_cat dog_follow dog_gait stella_stops clues clue_delivery progress minimap items memory_lifecycle audit_tooling boot gallery
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script docs/tools/audit_idle_guidance.gd -- out=/tmp/idle-guidance.json
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script docs/tools/bot_playtest.gd -- policy=rush,resourceful seeds=6 level=1 max=160 verbose=1 quiet=1 out=/tmp/active-guidance.json
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script docs/tools/bot_playtest.gd -- policy=resourceful,resourceful seeds=2 level=1 max=160 verbose=1 quiet=1 out=/tmp/guidance-replay.json
GUIDANCE_SHOTS=/tmp /Applications/Godot.app/Contents/MacOS/Godot --fixed-fps 60 --path . --rendering-method gl_compatibility --script docs/tools/test_guidance_hud.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release Web build/web/index.html
```
