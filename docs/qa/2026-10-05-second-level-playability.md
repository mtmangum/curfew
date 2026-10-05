# Level 2 playability follow-up — 2026-10-05

Implements A2 from the [playability audit](../audits/2026-10-04/playability/REPORT.md): give browser players a manageable second journey and a readable chance to react to patrols.

## Changes

| Level 2 rule | Audited baseline | Now |
| --- | --- | --- |
| Patrol fraction | 100% | 40% |
| Detection-rate multiplier / chase threshold | 1.0 / 0.2 | 0.35 / 0.7, matching level 1 |
| Cop chase speed; Nicole walks at 85 | 80 | 72 |
| Nearby car / skateboarder targets | 18 / 4 | 5 / 1 |
| Home distance | At least 4,500 | 2,200–4,200 |
| Scent interval when free and safe | 40–65 seconds | 10–15 seconds |
| Working phone booths | None | Retained |
| Street roster | Hobos, punks, zombies; lingering zombies | Hobos; punks, zombies and lingering pressure begin on level 3 |

The cold grade, fog, blackout and wind/sirens remain. Squirrels still end after level 1. Level 1 balance and the configured balance for levels 3+ are unchanged.

Patrols now show a yellow `?` while noticing Nicole or Stella, before uninterrupted sight becomes a chase. A persistent HUD warning gives the response: leave the beam; after pursuit starts, break sight and keep moving. Both the cop's larger bar and the HUD bar fill at the current level's actual chase threshold, rather than displaying raw exposure against 1.0. A chase displays a full red bar. Raw exposure continues to drive AI and audio; warning styling only updates when its state changes.

README, design principles, handoff, changelog, gallery level guide and character first-appearance labels are updated. General regression fixtures use level 3 for the full roster; zombie fixtures now exercise their new introductory level. The chase fixture explicitly uses dry-weather bark reach, while the level fixture still checks rain attenuation.

## Controlled behavior checks

Godot 4.7.2 on macOS, local changes based on `62cf5d4a373747ad32b6ad05f728dcb479c24d9a`. `test_second_level.gd` places moving, lit Nicole on an open road with Stella far away, then advances real cop detection at 60 Hz without actor movement.

| Distance / behavior | Audited time to chase | Current time to chase | Current visible warning before chase |
| --- | --- | --- | --- |
| 60 units, walking | 0.083 s | 0.817 s | 0.750 s |
| 100 units, walking | 0.117 s | 1.050 s | 0.950 s |
| 60 units, sneaking | 0.150 s | 1.483 s | 1.350 s |
| 100 units, sneaking | 0.200 s | 1.917 s | 1.750 s |

The warning clock starts when both the yellow mark and HUD warning appear. These are comparable controlled scenarios, not guaranteed reaction time at all distances: proximity, alerted cops, Stella, drag and prior suspicion still matter.

- Walking away for two seconds opens a 45-unit chase gap to approximately 71 units.
- Across 24 home seeds, the actual chooser selects five distinct clear doors inside the distance band.
- The undistracted scent fixture starts a useful hint within 10–15 seconds.
- Live spawning produced five nearby cars and one skateboarder, within the new targets.
- Half the chase threshold displays as half a bar on both level 2 and a later level; chase fills the bar. Warning clears once sight and suspicion have cleared.

Native visual evidence: [noticing](2026-10-05-second-level/noticing.png), [chase](2026-10-05-second-level/chase.png). [Fixture output](2026-10-05-second-level/fixture.log).

## Route survival

Twelve runs per level: six home seeds × rush/careful policy, real traffic, a 180-second ceiling. Bots know the destination, use A* routes and do not use carried items or intelligently escape a chase. Home seeds control destinations and traffic is seeded, but `Main._ready()` still randomizes global actor behavior. A8's reproducibility work remains open; the earlier baseline and these runs are not matched actor/event timelines.

| Measure | Current level 1 | Current level 2 | Earlier level 2 audit |
| --- | --- | --- | --- |
| Outcomes | 12 won | 3 won, 7 caught, 2 run over | 12 caught |
| Rush / careful wins | 6/6 / 6/6 | 2/6 / 1/6 | 0/6 / 0/6 |
| Duration range | 22.6–28.8 s | 25.6–65.3 s | 20.1–43.1 s |
| Chases / escapes | 0 / 0 | 9 / 2 | 16 / 2 |
| Runs receiving a home scent | 12/12 | 12/12 | 0/12 |
| First scent during route runs | 10.4–13.4 s | 11.6–15.7 s | None |
| Runs taking damage | 0 | 7 | 9, with overlapping sources |

The current level 2 sample reaches five distinct initial destination distances (2,565–4,188 units), versus four on level 1 (1,455–1,713). RunLog's `route` is straight-line starting distance, not walked path length. Level 2's first damage occurred at 13.7–39.2 seconds; car damage occurred in seven runs and skater damage in two. The sample clears the universal-failure concern, but capture and traffic remain substantial risks. The careful bot can wait or sneak when it should escape, so its lower win count does not establish that careful human play is worse.

Raw evidence: [level 1 JSON](2026-10-05-second-level/level-1.json) and [log](2026-10-05-second-level/level-1.log), [level 2 JSON](2026-10-05-second-level/level-2.json) and [log](2026-10-05-second-level/level-2.log), [aggregate](2026-10-05-second-level/summary.json).

## Verification and limits

All 11 focused groups passed: level settings/progression, warning/escape, core stealth, investigation, dog distractions, sleeping zombies, street characters, clues and pointer controls. All seven additional groups passed: boot, memory lifecycle, lighting, map/phones, pause, items and gallery. Results are recorded in [focused regressions](2026-10-05-second-level/regressions.log), [corrected fixture reruns](2026-10-05-second-level/final-regressions.log) and [additional regressions](2026-10-05-second-level/additional-regressions.log).

The normal release Web export completed successfully. Chrome loaded level 1, then selected and rendered level 2 through the existing LEVEL2 debug shortcut; the Sneak button remained interactive. This was a boot/transition smoke check, not a human route completion. Final local pack SHA-256: `e2f04a36ee0f9b1470290eae3e07ab0f7d6e7a0875c17716b326e7563c3dfdb1`.

Passing these mechanical checks is not beginner playability sign-off. Observe first-time players on both early levels: do they notice the yellow warning, leave the beam, understand Stella's cue, use phone help, recover from a chase and choose to continue? Check real phones; A4's broader HUD scaling remains open. The level 3 transition also still needs human assessment.

Reproduce:

```sh
python3 docs/tools/run_tests.py second_level first_level levels chase stealth_rules investigate stella_stops plaza_zombies street_people clues pointer_controls
python3 docs/tools/run_tests.py boot memory_lifecycle lightmap minimap pause items gallery
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script docs/tools/bot_playtest.gd -- policy=rush,careful seeds=6 runs=1 level=2 max=180 traffic=1 verbose=1 out=/tmp/level-2.json
BRIDGE_SHOTS=docs/qa/2026-10-05-second-level /Applications/Godot.app/Contents/MacOS/Godot --path . --script docs/tools/test_second_level.gd
```

Changes remain local; no commit, push or deployment performed.
