# Clue delivery and replay follow-up — 2026-10-05

Implements A5 from the [playability audit](../audits/2026-10-04/playability/REPORT.md), alongside the uncommitted [A4 responsive HUD](2026-10-05-compact-hud.md). Source HEAD remains `a17dc66`, with A3 verified in production. A4 and A5 are local changes, not yet committed or deployed.

## Player behavior

Ordinary explanations queue, including a one-shot pickup during another clue or the opening title. Item pickup no longer acts as an urgent warning. A cop's red ! still interrupts promptly; the unread interrupted explanation returns ahead of the ordinary backlog for a fresh, full reading interval. Repeated offers of the current/queued explanation cannot add duplicates. The queue has at most the 13 distinct rule/item catalogue entries.

The HUD finishes its fade-in, holds the card for the existing 4–7-second reading interval, then marks that explanation seen and fades out. A killed/replaced timer cannot complete another clue: completion carries the expected ID. Pausing freezes the bound tween and gameplay clock. End screens hide clues and reject their completion, so dying during a clue does not save it as read. The six-second start spacing and three-second opening grace use gameplay time. Clues remain automatic only on levels 1–3.

Pause → **Field guide** replays rule explanations and items unlocked for the current level, regardless of whether they were already marked seen. It opens at the carried item, otherwise the latest explanation or Stella's home cue. Previous/Next wrap through the entries, and Back returns to the pause menu. Browsing does not mark an automatic clue seen, reset it, use an item or move Nicole. No mandatory tutorial pause is added. Pointer explanations say to tap the item; keyboard instructions remain available in Controls.

The existing `curfew_clues` localStorage key/native JSON list is retained. Previously saved IDs stay saved; the field guide supplies replay for those legacy entries too. Unread queued cards are not stored as complete. The queue is local to a run; after death/reload the rules and unlocked items remain accessible in the guide, and an unread encounter can offer its explanation again.

## Verification

Godot 4.7.2 on macOS. [Delivery fixture](../tools/test_clue_delivery.gd), [headless output](2026-10-05-clue-delivery/fixture.log), [native output](2026-10-05-clue-delivery/native-fixture.log). All **18 assertions pass** using real Main updates, HUD tweens, item collection and GUI event dispatch.

| Scenario | Result |
| --- | --- |
| Scent → actual treat pickup | Scent remains; treat queues; neither is saved immediately |
| 100 duplicate encounter offers | Current/pending entries remain unique |
| Scent → cop warning | Red ! card reaches full opacity within 20 fixed-60-Hz frames; scent returns before the item |
| Eight seconds paused during the warning | Remaining reading time and gameplay clock stay fixed; no seen IDs saved |
| Field guide during that pause | Opens carried treat; browsing leaves automatic completion and steering unchanged |
| Every guide entry, 390 × 844 and rotated 844 × 390 | All 13 fit, with 16-pixel body text and targets at least 44 screen pixels; no menu downscaling |
| Four-action landscape pause menu | Resume/Sound/Controls/Field guide fit with 48-pixel targets |
| Resume after interruption | Scent returns with a full reading interval; partial reading stays unread |
| Completed restored scent | Saved once; queued treat follows |
| Death during treat, then nine seconds on end screen | Treat remains absent from serialized seen IDs |
| New scene using the serialized/parsed seen list | Unread treat is accepted again; full dwell saves it, then repeat offers are rejected |
| Item offered during title/grace | Retained until title clears, then displayed |
| 100 passes over all catalogue IDs | Current plus pending stays bounded at 13; invalid ID rejected |
| Reset with an old timer | Cancelled completion cannot repopulate seen IDs |

All **18 regression groups passed**: delivery, existing clue encounters, compact HUD, pointer controls, navigation/phones, pause, memory lifecycle, items, first level, second level, progression, scent priority, dog/cat, following, chase, stealth, minimap and boot. See [runner output](2026-10-05-clue-delivery/regressions.log). The memory fixture now also checks that clue controllers are released on disposal and on actual restarts with an active card and queued item. The navigation fixture explicitly cancels its previous card before testing the isolated phone interaction.

Inspected native evidence: [urgent warning](2026-10-05-clue-delivery/urgent-warning.png), [restored scent](2026-10-05-clue-delivery/restored-scent.png), [portrait item guide](2026-10-05-clue-delivery/portrait-item-guide.png), [portrait rule guide](2026-10-05-clue-delivery/portrait-rule-guide.png), [landscape item guide](2026-10-05-clue-delivery/landscape-item-guide.png), [four-action landscape pause](2026-10-05-clue-delivery/landscape-pause.png).

The normal Web export succeeded. Pack SHA-256: `67850e4a584031c948c655497830b8de01db08662d583a0da2ccdde847b3a83c`. In Chrome on an isolated localhost origin, actual pointer actions opened Pause/Field guide, browsed to the donut description, rotated from 844 × 390 to 390 × 844 with the description open, returned with Back and resumed. Text and controls remained contained and readable. Native screenshots above are distinct from browser emulation.

## Limits and follow-up

The persistence fixture disables real store writes, then serializes/parses the saved list into a new scene. It verifies which IDs would survive a visit, without changing the user's native teaching history. Physical Android Chrome/iOS Safari, focus-return reading, browser storage restrictions and actual beginner comprehension remain untested. A 4–7-second hold is a delivery rule, not evidence that every player has read or understood it. The guide offers voluntary rereading.

A browser tab retained from A4 went blank during the first A5 reload and Chrome labeled it at 830 MB. Closing that QA tab and opening a fresh one recovered rendering; a subsequent warm reload in that fresh tab also rendered successfully. This observation has not been attributed to game code or established as a memory trend; repeat reloads and actual device checks should include it. The existing native restart/helper checks pass.

Native fixtures exited and the localhost server was stopped. The computer-use window became unavailable during final cleanup, so closure of the last browser QA tab could not be verified.

A6 is the next implementation item: safe optional practice and useful level-transition teaching, while preserving the short first win.

## Reproduce

```sh
python3 docs/tools/run_tests.py clue_delivery clues compact_hud pointer_controls navigation pause memory_lifecycle items first_level second_level levels scent_priority dog_cat dog_follow chase stealth_rules minimap boot
CLUE_SHOTS=docs/qa/2026-10-05-clue-delivery /Applications/Godot.app/Contents/MacOS/Godot --fixed-fps 60 --path . --script docs/tools/test_clue_delivery.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release Web build/web/index.html
```
