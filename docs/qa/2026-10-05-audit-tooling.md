# A8: reproducible playability audit tooling

Implemented locally on 2026-10-05 after `a17dc66`, alongside the unreleased A4–A7
work. No commit, push or deployment was performed. Production remains at A3.
This follow-up completes the tooling action in the [playability audit](../audits/2026-10-04/playability/REPORT.md#a8--p2-make-balance-comparisons-reproducible).

## Behavior and scope

`Main.audit_seed` is opt-in and applies before home/actor construction; `-1` keeps
ordinary play random. The traffic director is seeded before setup. Weather, rain
and sound use separate derived RNG streams in audit mode, and cop LOOK scanning
uses simulated play time rather than the system clock. Audit-only settings
variants apply before construction. Normal difficulty settings are unchanged.

The bot freezes the scene during construction and releases it at a common process
boundary. Without this, a warm scene created in `process_frame` could give some
children one extra tick compared with a cold deferred start. The focused test
caught this through rain and pickup animation states despite identical event logs;
final full-state replays pass. Standalone performance/crowd/depth/playability
construction fixtures also use the seed hook. Real-reload soak/restart tools still
exercise ordinary random retries.

Each simulation records seed/run/policy/level, settings, engine version, source
signature, initial actor/RNG state and its signature, and a stable destination ID.
The seed is shared across policies and reaction/speed variants. Matching signatures
must be checked before comparing outcomes; density/layout variants can legitimately
produce different initial rosters. The controller validates the simulated process
step against 1/60 second and reports a harness error for a different clock.

The shared audit-only A* planner uses a 10-unit grid, swept-circle clearance and
exact real-position/door connections. It serves bot and soak tools. It is not added
to the production gameplay loop. Bot recovery now also detects an unreached route
when Player has cleared its destination. No-path, steering and clock failures are
included in run counts and distinguished from game losses.

The original rush/sneak/careful policies remain. `items` adds directly reachable
item detours within 180 units and contextual use through the real pickup and item
systems. `escape` walks away from active nearby chasers using swept-clear headings,
favoring distance and broken sight; it replans the homeward route afterward.
`resourceful` combines both. Donuts are saved during pursuit, while a nearby chase
can trigger a carried extinguisher or coffee. Inventory is never granted and the
controller never teleports. Policy fixtures explicitly set initial chase positions
only to test the real AI and item effects.

## Telemetry schema 2

| Field | Meaning |
| --- | --- |
| `initial_home_distance` | Straight-line distance from the actual run origin to the door; retries use their respawn position |
| `best_home_distance` | Smallest observed straight-line distance to the door |
| `best_distance_gain_fraction` | Best radial distance reduction divided by initial distance; **not route completion** |
| `astar_path_length` | Audit planner's initial collision-aware grid reference length, including start and door connections; `-1` in ordinary play |
| `walked` | Observed player movement, including tugs and detours; independent of the reference length |
| `destination_id` / `destination` | Stable door-zone identity and its center; seeds need not select distinct homes |
| `items_found` / `items_used` | Pickups and real uses counted separately |
| Event `home_distance` / `home_distance_ratio` | Current straight-line distance and its ratio to initial distance |

The F3 readout and bot report use these explicit labels. Historical evidence is
unchanged: old `route` meant initial straight-line distance, and old `progress`
meant best radial distance gain. Old route-profile output used `route` differently
for A* length. New profile mode honors `level` and JSON `out` and uses the explicit
A* label. Production logging does not compute an expensive audit path.

## Verification and retained evidence

Godot 4.7.2, native headless, fixed 60 FPS. [Focused evidence](2026-10-05-audit-tooling/focused.log)
contains **17 passing checks**: cold/warm initial and final states, event replay,
sound-stream independence, changing run IDs, matched reaction/speed variants,
swept path connections, distinct distance metrics, stable destinations, actual
retry origin, a real treat pickup/use, a survived chase, saved donuts, a real
extinguisher cloud and opt-in overrides.

[Regression evidence](2026-10-05-audit-tooling/regressions.log) initially passed 17
of 18 groups. The traffic fixture placed its horn listener 200 units away, outside
level 3's rain-reduced 180-unit hearing radius. The fixture now uses the configured
radius and clears its listener's seeing state; it also opts into a known seed.
The [traffic rerun](2026-10-05-audit-tooling/regressions-traffic.log) passes. The
final result covers all 18 selected groups: audit tooling, RunLog, audio cache,
audio, footsteps, boot, saved progress, first walk, chase, investigation, stealth,
police, traffic, levels, both introductory levels, items and memory lifecycle.

Raw coroutine fixtures still emit legacy exit-resource warnings. The dedicated
memory-lifecycle group passes its real-restart and weak-reference release checks;
this follow-up does not claim that all exit diagnostics have been eliminated.

[Comparison verification](2026-10-05-audit-tooling/comparisons.log) checks the
retained cohorts without dropping failed game runs:

| Cohort | Inputs and distinct destinations | Result |
| --- | --- | --- |
| [Level 1](2026-10-05-audit-tooling/level1.json) | Six seeds, five policies; 30 runs, four homes | 30 wins. Median homecoming: rush 26.5s; careful/escape 26.2s; items/resourceful 24.6s |
| [Level 2](2026-10-05-audit-tooling/level2.json) | Three seeds, rush/items/resourceful; nine runs, three homes | Rush: 3 wins. Items: 1 win, 2 captures. Resourceful: 1 win, 1 capture, 1 car death |
| [Level 3 replay](2026-10-05-audit-tooling/level3-repeat.json) | Two seeds × two run IDs × two identical policy runs | All four pairs match the **entire JSON record**, including event timelines; two captures and two car deaths per set, one recorded escape |
| [Level 3 variant](2026-10-05-audit-tooling/level3-variant.json) | Same four inputs, `cop_sight=0.7` | Every initial signature, actor/RNG snapshot and destination matches its baseline |
| [Level 2 profile](2026-10-05-audit-tooling/profile-level2.json) | Three seeds, explicit level 2, JSON output | Selected level, initial signatures and A* lengths match the played level 2 records |

All cohorts share source signature:
`a3a059c951fe1fde55e93fc99ff0dc5a11ad2d12f75b603cb0d37204dc1f3bee`.

The [normal Web export](2026-10-05-audit-tooling/export.log) succeeds without
script/parse errors. Local pack SHA256:
`7dfd411083eba082f6ee40f4bba3385993e66288c4aa7c09b80ed2f215e61865`.
The [clock guard](2026-10-05-audit-tooling/clock-guard.log) rejects a deliberate
30 FPS run with exit code 1. At A8 verification, GDScript sources matched the cohort signature; later guidance/HUD work has a different source signature.
No browser/device run or deployment is claimed; no local server was started.

## What the measurements establish

Replays and matched initial conditions are now usable for controlled simulation
comparisons. Level 1 keeps short successful routes in the tested sample. The bots
know home, inspect local actor states and use simplified traffic prediction and
item judgments. These are not discovery, comprehension or retention measurements.
The weaker level 2 item-policy results show that a policy name is not evidence of
human competence: waiting, detours, sneaking during a chase in the isolated items
baseline, and imperfect escape/traffic choices can all change survival. These
small samples do not justify a new balance change or establish that items are bad.

Before using rates as acceptance gates, observe first-time players without coaching
on desktop and touch. Record time to first successful homecoming, recognition of
the scent/item controls, response to warnings, the level 2 transition and willingness
to continue. This remains the next step under the free-browser-game engagement
principle. Cross-platform bit-identical replay is unverified; reproduce with the
same engine, configuration, sources, fixed clock and input settings.

## Reproduce

```sh
python3 docs/tools/run_tests.py audit_tooling runlog audio_cache audio footsteps boot progress first_walk chase investigate stealth_rules police traffic levels first_level second_level items memory_lifecycle
python3 docs/tools/verify_audit_results.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script docs/tools/bot_playtest.gd -- policy=rush,careful,items,escape,resourceful seeds=6 level=1 max=140 verbose=1 quiet=1 out=/tmp/a8-level1.json
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script docs/tools/bot_playtest.gd -- policy=rush,items,resourceful seeds=3 level=2 max=160 verbose=1 quiet=1 out=/tmp/a8-level2.json
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script docs/tools/bot_playtest.gd -- policy=resourceful,resourceful seeds=2 runs=2 level=3 max=140 verbose=1 quiet=1 out=/tmp/a8-repeat.json
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script docs/tools/bot_playtest.gd -- policy=resourceful seeds=2 runs=2 level=3 max=140 sight=0.7 verbose=1 quiet=1 out=/tmp/a8-variant.json
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script docs/tools/bot_playtest.gd -- policy=profile seeds=3 level=2 out=/tmp/a8-profile.json
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release Web build/web/index.html
```
