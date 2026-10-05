# Optional first-walk practice — 2026-10-05

A6 is implemented locally after A4/A5. Level 1 offers an accessible treat and a
readable patrol without adding a required lesson or delaying homecoming. The
acceptance criterion involving real beginners is still pending. Nothing in this
follow-up has been committed or deployed; production remains at A3.

## What changed

- One existing treat is moved to clear ground in the starting plaza. In the tested
  city it is at `(350, 2730)`, 100 units from Nicole, with an unobstructed walk of
  radius 10 from the start. Its usual pulsing ring and bone icon remain; walking
  over it picks it up, and the queued item explanation describes its use.
- One existing level-1 cop is moved to a 140-unit pavement segment east of the
  plaza, from `(1492, 2815)` to `(1352, 2815)`. The placement search uses reserved
  patrol pavement, checks collision along the whole segment and avoids the door.
  It preserves the 1,000-unit safe zone and the existing cop/item counts. Normal
  level-2 placement, home bands, traffic and detection/escape tuning are retained.
- A calm cop within 200 units offers a one-time explanation of Sneak and going
  around the beam only when on screen with clear sight. Walls and active steam
  suppress that trigger. The card queues like other ordinary teaching and can be
  replayed in the field guide, which now has nine rule entries plus unlocked items.
- Homecoming previews the next walk: level 2's longer cold route and road/patrol
  pressure, then level 3's torch tradeoff and moving past zombies. Later previews
  cover barricades and neon corner distractions. No item-use or patrol-completion
  flag gates a win. The preview stays steady instead of blinking.
- Rotating an end screen from desktop width into portrait explicitly resizes its
  container and wraps the title. The new preview exposed the retained-width bug.

## Verification

[Headless fixture](2026-10-05-first-walk/fixture.log) and
[native fixture](2026-10-05-first-walk/native-fixture.log) each pass 13 checks:
clear treat access, optional patrol placement, collision/safe-zone/door clearance,
30 seconds of real patrol movement without a stuck or threatened start, actual
pickup and 30-second treat effect, visible and occluded clue triggers, unrestricted
homecoming, steady readable cards at 390×844 and 844×390, unchanged level-2
placement and the level-3 preview. The fixture freezes unrelated actors; it is a
mechanics/layout check, not a simulated beginner session.

[Regression results](2026-10-05-first-walk/regressions.log): 20 of 20 groups pass:
first_walk, compact_hud, clue_delivery, clues, first_level, second_level,
navigation, levels, pause, memory_lifecycle, items, start_safe, pointer_controls,
scent_priority, dog_cat, dog_follow, chase, stealth_rules, minimap and boot.
The clue-delivery check includes all 14 level-3 guide entries.

Native screenshots were visually inspected:

- [Starting treat](2026-10-05-first-walk/starting-treat.png).
- [Visible side-street patrol and explanation](2026-10-05-first-walk/optional-patrol.png).
- [Portrait homecoming](2026-10-05-first-walk/next-walk-390x844.png).
- [Landscape homecoming](2026-10-05-first-walk/next-walk-844x390.png).

The [final route cohort](2026-10-05-first-walk/routes.log), with
[raw results](2026-10-05-first-walk/routes.json), uses six configured home seeds and
two policies with real traffic. All six shortest-route and all six cautious runs
win, with a median of 26.1 seconds in each policy, no sightings/chases and no life
lost. This confirms that practice can still be bypassed on those known routes.
The bots know home and do not assess whether a player noticed the treat or learned
Sneak. These are six seed values, not a claim of six distinct destination buildings.

An earlier development cohort had one cautious timeout beside a waypoint without
a sighting/chase. That observation has not been attributed to the practice patrol;
the final cohort cleared all routes. Global actor randomness is still reset by
`Main.randomize()`, so this is not a paired, fully reproducible balance comparison.
A8 retains the RNG/logging and item-aware/escape-aware bot work. Existing headless
fixture/bot exit resource warnings remain in the raw logs; the dedicated
memory-lifecycle checks pass, including actual restarts and clue-controller release.

The normal Web export succeeds without parse/script errors. Local pack SHA256:
`878c9b078b58bd623c8a006aab21169b42e613fb854224c5d5dd860b37efabc6`.
Chrome computer-use returned `cgWindowNotFound`, so no fresh A6 browser runtime
check is claimed. Physical Android/iOS and touch play sessions remain pending.
No local Web server was started for this check; fixture processes exited.

## Beginner observation still required

Watch new players without explaining controls first. Record whether they notice
and pick up the treat, understand the item slot, explain Stella's scent cue, and
demonstrate Sneak or choose a safe way around the patrol. Record discovery time,
mistakes, time to first homecoming and whether they choose the next walk. Include
portrait touch controls and the transition to level 2. Do not require practice to
count as a successful first run. A7 progress saving and causal retry feedback are next.

## Reproduce

```sh
python3 docs/tools/run_tests.py first_walk compact_hud clue_delivery clues first_level second_level navigation levels pause memory_lifecycle items start_safe pointer_controls scent_priority dog_cat dog_follow chase stealth_rules minimap boot
FIRST_WALK_SHOTS=docs/qa/2026-10-05-first-walk /Applications/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --rendering-method gl_compatibility --script docs/tools/test_first_walk.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script docs/tools/bot_playtest.gd -- policy=rush,careful seeds=6 level=1 max=180 quiet=1 out=docs/qa/2026-10-05-first-walk/routes.json
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release Web build/web/index.html
```
